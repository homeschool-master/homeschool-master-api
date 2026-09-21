# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Assignments', type: :request do
  def sign_in(teacher)
    post api_v1_auth_login_url, params: { email: teacher.email, password: 'password123' }
  end

  def data
    JSON.parse(response.body)['data']
  end

  describe 'GET /api/v1/assignments' do
    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        @subject = FactoryBot.create(:subject, teacher: @teacher, name: 'Math')
        sign_in(@teacher)
      end

      it 'returns success' do
        get api_v1_assignments_url
        expect(response).to have_http_status(:ok)
      end

      it 'orders by due date with undated last' do
        FactoryBot.create(:assignment, teacher: @teacher, subject: @subject, title: 'Undated', due_date: nil)
        FactoryBot.create(:assignment, teacher: @teacher, subject: @subject, title: 'Later',
                                       due_date: Date.new(2026, 10, 1))
        FactoryBot.create(:assignment, teacher: @teacher, subject: @subject, title: 'Soon',
                                       due_date: Date.new(2026, 9, 5))
        get api_v1_assignments_url
        expect(data.map { |a| a['title'] }).to eq(%w[Soon Later Undated])
      end

      it "excludes other teachers' assignments" do
        other = FactoryBot.create(:teacher)
        FactoryBot.create(:assignment, teacher: other, title: 'NotMine')
        FactoryBot.create(:assignment, teacher: @teacher, subject: @subject, title: 'Mine')
        get api_v1_assignments_url
        expect(data.map { |a| a['title'] }).to eq(['Mine'])
      end

      it 'filters by subject' do
        other_subject = FactoryBot.create(:subject, teacher: @teacher, name: 'Science')
        FactoryBot.create(:assignment, teacher: @teacher, subject: @subject, title: 'Math work')
        FactoryBot.create(:assignment, teacher: @teacher, subject: other_subject, title: 'Science work')
        get api_v1_assignments_url, params: { subject_id: @subject.id }
        expect(data.map { |a| a['title'] }).to eq(['Math work'])
      end

      it 'filters by due range, inclusive' do
        FactoryBot.create(:assignment, teacher: @teacher, subject: @subject, title: 'In',
                                       due_date: Date.new(2026, 9, 10))
        FactoryBot.create(:assignment, teacher: @teacher, subject: @subject, title: 'Out',
                                       due_date: Date.new(2026, 11, 1))
        get api_v1_assignments_url, params: { due_from: '2026-09-01', due_to: '2026-09-30' }
        expect(data.map { |a| a['title'] }).to eq(['In'])
      end

      it 'rejects an unparseable due filter' do
        get api_v1_assignments_url, params: { due_from: 'whenever' }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'nests the grades on each assignment' do
        assignment = FactoryBot.create(:assignment, teacher: @teacher, subject: @subject, points_possible: 20)
        student = FactoryBot.create(:student, teacher: @teacher)
        FactoryBot.create(:assignment_grade, assignment: assignment, student: student, points_earned: 15)
        get api_v1_assignments_url
        grade = data.first['grades'].first
        expect(grade['student_id']).to eq(student.id)
        expect(grade['percentage'].to_f).to eq(75.0)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get api_v1_assignments_url
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/assignments/:id' do
    before do
      @teacher = FactoryBot.create(:teacher)
      @assignment = FactoryBot.create(:assignment, teacher: @teacher)
      sign_in(@teacher)
    end

    it 'returns the assignment' do
      get api_v1_assignment_url(@assignment)
      expect(response).to have_http_status(:ok)
      expect(data['id']).to eq(@assignment.id)
    end

    it 'returns not found when it does not exist' do
      get api_v1_assignment_url('00000000-0000-0000-0000-000000000000')
      expect(response).to have_http_status(:not_found)
    end

    it "returns not found for another teacher's assignment" do
      other = FactoryBot.create(:teacher)
      get api_v1_assignment_url(FactoryBot.create(:assignment, teacher: other))
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when not authenticated' do
    it 'rejects show' do
      get api_v1_assignment_url(FactoryBot.create(:assignment))
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects create' do
      post api_v1_assignments_url, params: { title: 'Sneak' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects update' do
      patch api_v1_assignment_url(FactoryBot.create(:assignment)), params: { title: 'Sneak' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects destroy, leaving the row in place' do
      assignment = FactoryBot.create(:assignment)
      expect { delete api_v1_assignment_url(assignment) }.not_to change(Assignment, :count)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/assignments' do
    before do
      @teacher = FactoryBot.create(:teacher)
      @subject = FactoryBot.create(:subject, teacher: @teacher)
      @student = FactoryBot.create(:student, teacher: @teacher)
      sign_in(@teacher)
    end

    def valid_params(**overrides)
      { subject_id: @subject.id, title: 'Chapter 4 problems', due_date: '2026-09-25',
        points_possible: 20, weight: 2 }.merge(overrides)
    end

    it 'creates the assignment' do
      expect { post api_v1_assignments_url, params: valid_params }
        .to change(@teacher.assignments, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it 'defaults points_possible and weight' do
      post api_v1_assignments_url, params: { subject_id: @subject.id, title: 'Reading' }
      expect(data['points_possible'].to_f).to eq(100.0)
      expect(data['weight'].to_f).to eq(1.0)
    end

    it 'assigns the listed students as unmarked grades' do
      second = FactoryBot.create(:student, teacher: @teacher)
      post api_v1_assignments_url, params: valid_params(student_ids: [@student.id, second.id])
      expect(data['grades'].length).to eq(2)
      expect(data['grades'].map { |g| g['graded'] }).to all(be(false))
      expect(data['grades'].map { |g| g['points_earned'] }).to all(be_nil)
    end

    it 'creates with no students at all' do
      post api_v1_assignments_url, params: valid_params
      expect(response).to have_http_status(:created)
      expect(data['grades']).to be_empty
    end

    it "rejects another teacher's student and creates nothing" do
      other_student = FactoryBot.create(:student, teacher: FactoryBot.create(:teacher))
      expect { post api_v1_assignments_url, params: valid_params(student_ids: [other_student.id]) }
        .not_to change(Assignment, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']['details']['student_ids'])
        .to include('must all belong to the current teacher')
    end

    it 'rejects a mixed list of own and foreign students' do
      other_student = FactoryBot.create(:student, teacher: FactoryBot.create(:teacher))
      post api_v1_assignments_url, params: valid_params(student_ids: [@student.id, other_student.id])
      expect(response).to have_http_status(:unprocessable_content)
      expect(AssignmentGrade.count).to eq(0)
    end

    it "rejects another teacher's subject" do
      other_subject = FactoryBot.create(:subject, teacher: FactoryBot.create(:teacher))
      post api_v1_assignments_url, params: valid_params(subject_id: other_subject.id)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'requires a title' do
      post api_v1_assignments_url, params: valid_params(title: '')
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects zero points_possible' do
      post api_v1_assignments_url, params: valid_params(points_possible: 0)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'ignores an injected teacher_id' do
      other = FactoryBot.create(:teacher)
      post api_v1_assignments_url, params: valid_params(teacher_id: other.id)
      expect(data['teacher_id']).to eq(@teacher.id)
    end
  end

  describe 'PATCH /api/v1/assignments/:id' do
    before do
      @teacher = FactoryBot.create(:teacher)
      @subject = FactoryBot.create(:subject, teacher: @teacher)
      @assignment = FactoryBot.create(:assignment, teacher: @teacher, subject: @subject, points_possible: 20)
      @student = FactoryBot.create(:student, teacher: @teacher)
      @grade = FactoryBot.create(:assignment_grade, assignment: @assignment,
                                                    student: @student, points_earned: 15)
      sign_in(@teacher)
    end

    it 'updates the fields' do
      patch api_v1_assignment_url(@assignment), params: { title: 'Chapter 5', weight: 3 }
      expect(response).to have_http_status(:ok)
      @assignment.reload
      expect(@assignment.title).to eq('Chapter 5')
      expect(@assignment.weight).to eq(3)
    end

    it 'keeps an existing score when the student stays on the assignment' do
      second = FactoryBot.create(:student, teacher: @teacher)
      patch api_v1_assignment_url(@assignment), params: { student_ids: [@student.id, second.id] }
      expect(@grade.reload.points_earned).to eq(15)
      expect(@assignment.reload.assignment_grades.count).to eq(2)
    end

    it 'unassigning a student deletes their score, which is destructive by design' do
      patch api_v1_assignment_url(@assignment), params: { student_ids: [] }, as: :json
      expect(AssignmentGrade.where(id: @grade.id)).to be_empty
    end

    # Form encoding drops an empty array on the floor, so a client that sends
    # one that way is asking for nothing rather than for everyone removed.
    it 'leaves the set alone when an empty array cannot survive the encoding' do
      patch api_v1_assignment_url(@assignment), params: { student_ids: [] }
      expect(@assignment.reload.assignment_grades.count).to eq(1)
    end

    it 'leaves the assigned set alone when student_ids is not sent' do
      patch api_v1_assignment_url(@assignment), params: { title: 'Renamed' }
      expect(@assignment.reload.assignment_grades.count).to eq(1)
      expect(@grade.reload.points_earned).to eq(15)
    end

    it "rejects another teacher's student and changes nothing" do
      other_student = FactoryBot.create(:student, teacher: FactoryBot.create(:teacher))
      patch api_v1_assignment_url(@assignment), params: { title: 'Hijack', student_ids: [other_student.id] }
      expect(response).to have_http_status(:unprocessable_content)
      expect(@assignment.reload.title).not_to eq('Hijack')
      expect(@grade.reload.points_earned).to eq(15)
    end

    it "returns not found for another teacher's assignment" do
      other = FactoryBot.create(:teacher)
      patch api_v1_assignment_url(FactoryBot.create(:assignment, teacher: other)), params: { title: 'Nope' }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/v1/assignments/:id' do
    before do
      @teacher = FactoryBot.create(:teacher)
      @assignment = FactoryBot.create(:assignment, teacher: @teacher)
      sign_in(@teacher)
    end

    it 'removes the assignment and its grades' do
      FactoryBot.create(:assignment_grade, assignment: @assignment,
                                           student: FactoryBot.create(:student, teacher: @teacher))
      expect { delete api_v1_assignment_url(@assignment) }.to change(AssignmentGrade, :count).by(-1)
      expect(response).to have_http_status(:no_content)
      expect(Assignment.where(id: @assignment.id)).to be_empty
    end

    it "returns not found for another teacher's assignment" do
      other = FactoryBot.create(:teacher)
      theirs = FactoryBot.create(:assignment, teacher: other)
      expect { delete api_v1_assignment_url(theirs) }.not_to change(Assignment, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
  # Whether a weight is the teacher's own is decided by whether she set it, not
  # by what she set it to. The case that drove the change is a weight she types
  # that happens to equal the default: under the old rule that counted as
  # inherited, and the next change to the default moved work she had settled.
  describe 'who owns an assignment weight' do
    before do
      @teacher = FactoryBot.create(:teacher)
      sign_in(@teacher)
      @subject = FactoryBot.create(:subject, teacher: @teacher)
      @test_type = @teacher.assignment_types.find_by(name: 'Test')
      @test_type.update!(default_weight: 3)
    end

    def create_assignment(params = {})
      post api_v1_assignments_url, params: {
        subject_id: @subject.id, assignment_type_id: @test_type.id, title: 'Unit test'
      }.merge(params)
      JSON.parse(response.body)['data']
    end

    def reload_weight(id)
      Assignment.find(id).then { |a| [a.weight, a.weight_overridden] }
    end

    it 'inherits when no weight is sent at all' do
      body = create_assignment

      expect(body['weight'].to_f).to eq(3.0)
      expect(body['weight_overridden']).to be(false)
    end

    it 'counts a weight she sent as hers' do
      body = create_assignment(weight: 5)

      expect(body['weight'].to_f).to eq(5.0)
      expect(body['weight_overridden']).to be(true)
    end

    it 'counts a weight she sent as hers even when it equals the default' do
      body = create_assignment(weight: 3)

      expect(body['weight'].to_f).to eq(3.0)
      expect(body['weight_overridden']).to be(true)
    end

    it 'leaves a weight she typed alone when the default later changes' do
      body = create_assignment(weight: 3)
      AssignmentTypeDefaultWeight.call(type: @test_type, weight: 5, mode: 'all')

      expect(reload_weight(body['id'])).to eq([3, true])
    end

    it 'moves an inherited weight when the default later changes' do
      body = create_assignment
      AssignmentTypeDefaultWeight.call(type: @test_type, weight: 5, mode: 'all')

      expect(reload_weight(body['id'])).to eq([5, false])
    end

    it 'leaves the weight and its owner alone on an edit that does not mention it' do
      body = create_assignment(weight: 5)
      patch api_v1_assignment_url(body['id']), params: { title: 'Renamed' }

      expect(reload_weight(body['id'])).to eq([5, true])
    end

    it 'takes a weight on an edit as hers' do
      body = create_assignment
      patch api_v1_assignment_url(body['id']), params: { weight: 2 }

      expect(reload_weight(body['id'])).to eq([2, true])
    end

    # The way back: a null weight hands the assignment to its type again.
    it 'hands it back to the type default when the weight is cleared' do
      body = create_assignment(weight: 5)
      patch api_v1_assignment_url(body['id']), params: { weight: nil }.to_json,
                                               headers: { 'Content-Type' => 'application/json' }

      expect(reload_weight(body['id'])).to eq([3, false])
    end

    it 'follows the default again after being handed back' do
      body = create_assignment(weight: 5)
      patch api_v1_assignment_url(body['id']), params: { weight: nil }.to_json,
                                               headers: { 'Content-Type' => 'application/json' }
      AssignmentTypeDefaultWeight.call(type: @test_type, weight: 4, mode: 'all')

      expect(reload_weight(body['id'])).to eq([4, false])
    end

    it 'allows zero, which is how practice work counts for nothing' do
      body = create_assignment(weight: 0)

      expect(body['weight'].to_f).to eq(0.0)
      expect(body['weight_overridden']).to be(true)
    end

    # No cap: a large weight is a real thing to want, and the form warns rather
    # than refusing. A negative one is not.
    it 'allows a large weight' do
      body = create_assignment(weight: 30)

      expect(response).to have_http_status(:created)
      expect(body['weight'].to_f).to eq(30.0)
    end

    it 'refuses a negative weight' do
      create_assignment(weight: -1)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses a negative default weight on a type' do
      patch api_v1_assignment_type_url(@test_type), params: { default_weight: -1 }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
