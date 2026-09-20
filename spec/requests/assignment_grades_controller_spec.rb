# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::AssignmentGrades', type: :request do
  def sign_in(teacher)
    post api_v1_auth_login_url, params: { email: teacher.email, password: 'password123' }
  end

  def data
    JSON.parse(response.body)['data']
  end

  context 'when authenticated' do
    before do
      @teacher = FactoryBot.create(:teacher)
      @subject = FactoryBot.create(:subject, teacher: @teacher)
      @assignment = FactoryBot.create(:assignment, teacher: @teacher, subject: @subject, points_possible: 20)
      @student = FactoryBot.create(:student, teacher: @teacher)
      @grade = FactoryBot.create(:assignment_grade, assignment: @assignment, student: @student)
      sign_in(@teacher)
    end

    describe 'GET grades' do
      it 'lists the grades on the assignment' do
        get api_v1_assignment_grades_url(@assignment)
        expect(response).to have_http_status(:ok)
        expect(data.map { |g| g['student_id'] }).to eq([@student.id])
      end

      it "returns not found for another teacher's assignment" do
        other = FactoryBot.create(:teacher)
        get api_v1_assignment_grades_url(FactoryBot.create(:assignment, teacher: other))
        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'PATCH a grade' do
      # 15 out of 20 is 75 per cent, worked out by hand.
      it 'records a score and derives the percentage' do
        patch api_v1_assignment_grade_url(@assignment, @grade), params: { points_earned: 15 }
        expect(response).to have_http_status(:ok)
        expect(data['points_earned'].to_f).to eq(15.0)
        expect(data['percentage'].to_f).to eq(75.0)
        expect(data['graded']).to be(true)
      end

      it 'stamps graded_at on the row' do
        patch api_v1_assignment_grade_url(@assignment, @grade), params: { points_earned: 15 }
        expect(@grade.reload.graded_at).to be_present
      end

      it 'records an explicit zero as a real score' do
        patch api_v1_assignment_grade_url(@assignment, @grade), params: { points_earned: 0 }
        expect(data['graded']).to be(true)
        expect(data['percentage'].to_f).to eq(0.0)
      end

      it 'clears a score back to unmarked' do
        @grade.update!(points_earned: 15)
        patch api_v1_assignment_grade_url(@assignment, @grade), params: { points_earned: nil }, as: :json
        expect(data['graded']).to be(false)
        expect(@grade.reload.graded_at).to be_nil
      end

      it 'accepts a score above what the work is out of' do
        patch api_v1_assignment_grade_url(@assignment, @grade), params: { points_earned: 22 }
        expect(response).to have_http_status(:ok)
        expect(data['percentage'].to_f).to eq(110.0)
      end

      it 'rejects a negative score' do
        patch api_v1_assignment_grade_url(@assignment, @grade), params: { points_earned: -1 }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'saves notes alongside the score' do
        patch api_v1_assignment_grade_url(@assignment, @grade),
              params: { points_earned: 18, notes: 'Neat working' }
        expect(@grade.reload.notes).to eq('Neat working')
      end

      it 'cannot move a grade to another student' do
        other_student = FactoryBot.create(:student, teacher: @teacher)
        patch api_v1_assignment_grade_url(@assignment, @grade), params: { student_id: other_student.id }
        expect(@grade.reload.student_id).to eq(@student.id)
      end

      it 'returns not found for a grade on a different assignment' do
        elsewhere = FactoryBot.create(:assignment, teacher: @teacher, subject: @subject)
        stray = FactoryBot.create(:assignment_grade, assignment: elsewhere, student: @student)
        patch api_v1_assignment_grade_url(@assignment, stray), params: { points_earned: 5 }
        expect(response).to have_http_status(:not_found)
      end

      it "returns not found for another teacher's grade, leaving the score alone" do
        other = FactoryBot.create(:teacher)
        their_assignment = FactoryBot.create(:assignment, teacher: other)
        their_grade = FactoryBot.create(:assignment_grade, assignment: their_assignment,
                                                           student: FactoryBot.create(:student, teacher: other),
                                                           points_earned: 5)
        patch api_v1_assignment_grade_url(their_assignment, their_grade), params: { points_earned: 100 }
        expect(response).to have_http_status(:not_found)
        expect(their_grade.reload.points_earned).to eq(5)
      end
    end
  end

  # A teacher can score by letter instead of by percentage. The letter becomes
  # a number once, here, and the number is what everything downstream uses.
  describe 'scoring by letter' do
    before do
      @teacher = FactoryBot.create(:teacher)
      sign_in(@teacher)
      @assignment = FactoryBot.create(:assignment, teacher: @teacher,
                                                   subject: FactoryBot.create(:subject, teacher: @teacher),
                                                   points_possible: 100)
      @grade = FactoryBot.create(:assignment_grade, assignment: @assignment,
                                                    student: FactoryBot.create(:student, teacher: @teacher))
    end

    def patch_grade(params)
      patch api_v1_assignment_grade_url(@assignment, @grade), params: params
      JSON.parse(response.body)
    end

    it 'turns the letter into a score' do
      body = patch_grade(entered_letter: 'A')

      expect(response).to have_http_status(:ok)
      expect(body['data']['points_earned'].to_f).to eq(95.0)
    end

    it 'remembers that it was entered as a letter' do
      body = patch_grade(entered_letter: 'B')
      expect(body['data']['entered_letter']).to eq('B')
    end

    it 'takes the letter as a share of what the work is out of' do
      @assignment.update!(points_possible: 20)
      body = patch_grade(entered_letter: 'A')

      expect(body['data']['points_earned'].to_f).to eq(19.0)
      expect(body['data']['percentage'].to_f).to eq(95.0)
    end

    it 'accepts a lowercase letter' do
      body = patch_grade(entered_letter: 'c')
      expect(body['data']['entered_letter']).to eq('C')
    end

    it 'refuses a letter that is not on the scale' do
      patch_grade(entered_letter: 'A+')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(@grade.reload.points_earned).to be_nil
    end

    it 'derives every entered letter back to the same letter' do
      LetterScale.letters.each do |letter|
        patch_grade(entered_letter: letter)
        percentage = JSON.parse(response.body)['data']['percentage'].to_f

        expect(LetterScale.letter_for(percentage)).to eq(letter)
      end
    end

    it 'forgets the letter when a number is typed over it' do
      patch_grade(entered_letter: 'A')
      body = patch_grade(points_earned: 72)

      expect(body['data']['entered_letter']).to be_nil
      expect(body['data']['points_earned'].to_f).to eq(72.0)
    end

    it 'forgets the letter when the mark is cleared' do
      patch_grade(entered_letter: 'A')
      body = patch_grade(points_earned: '')

      expect(body['data']['entered_letter']).to be_nil
      expect(body['data']['graded']).to be(false)
    end

    it 'lets the letter win when a number rides along with it' do
      body = patch_grade(entered_letter: 'A', points_earned: 12)
      expect(body['data']['points_earned'].to_f).to eq(95.0)
    end

    it 'keeps the letter when only the note changes' do
      patch_grade(entered_letter: 'A')
      body = patch_grade(notes: 'Neat work')

      expect(body['data']['entered_letter']).to eq('A')
      expect(body['data']['points_earned'].to_f).to eq(95.0)
    end
  end

  context 'when not authenticated' do
    before do
      @assignment = FactoryBot.create(:assignment)
      @grade = FactoryBot.create(:assignment_grade, assignment: @assignment,
                                                    student: FactoryBot.create(:student,
                                                                               teacher: @assignment.teacher))
    end

    it 'rejects index' do
      get api_v1_assignment_grades_url(@assignment)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects update, leaving the score alone' do
      patch api_v1_assignment_grade_url(@assignment, @grade), params: { points_earned: 100 }
      expect(response).to have_http_status(:unauthorized)
      expect(@grade.reload.points_earned).to be_nil
    end
  end
end
