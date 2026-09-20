# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Tasks', type: :request do
  def sign_in(teacher)
    post api_v1_auth_login_url, params: { email: teacher.email, password: 'password123' }
  end

  def titles_in_response
    JSON.parse(response.body)['data'].map { |task| task['title'] }
  end

  describe 'GET /api/v1/tasks' do
    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        sign_in(@teacher)
      end

      it 'returns success' do
        get api_v1_tasks_url
        expect(response).to have_http_status(:ok)
      end

      it "returns the teacher's tasks, soonest due first with undated last" do
        FactoryBot.create(:task, :undated, teacher: @teacher, title: 'Undated')
        FactoryBot.create(:task, teacher: @teacher, title: 'Later', due_date: Date.new(2026, 10, 5))
        FactoryBot.create(:task, teacher: @teacher, title: 'Soon', due_date: Date.new(2026, 9, 20))
        get api_v1_tasks_url
        expect(titles_in_response).to eq(%w[Soon Later Undated])
      end

      it 'includes completed tasks when no filter is given' do
        FactoryBot.create(:task, teacher: @teacher, title: 'Open')
        FactoryBot.create(:task, :completed, teacher: @teacher, title: 'Done')
        get api_v1_tasks_url
        expect(titles_in_response).to contain_exactly('Open', 'Done')
      end

      it "excludes other teachers' tasks" do
        other = FactoryBot.create(:teacher)
        FactoryBot.create(:task, teacher: other, title: 'NotMine')
        FactoryBot.create(:task, teacher: @teacher, title: 'Mine')
        get api_v1_tasks_url
        expect(titles_in_response).to eq(['Mine'])
      end

      it 'exposes both faces of completion' do
        FactoryBot.create(:task, :completed, teacher: @teacher, title: 'Done')
        get api_v1_tasks_url
        data = JSON.parse(response.body)['data'].first
        expect(data['completed']).to be(true)
        expect(data['completed_at']).to be_present
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get api_v1_tasks_url
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/tasks filtering' do
    before do
      @teacher = FactoryBot.create(:teacher)
      sign_in(@teacher)
      @overdue = FactoryBot.create(:task, teacher: @teacher, title: 'Overdue', due_date: Date.new(2026, 9, 1))
      @soon = FactoryBot.create(:task, teacher: @teacher, title: 'Soon', due_date: Date.new(2026, 9, 20))
      @later = FactoryBot.create(:task, teacher: @teacher, title: 'Later', due_date: Date.new(2026, 12, 1))
      @undated = FactoryBot.create(:task, :undated, teacher: @teacher, title: 'Undated')
      @done = FactoryBot.create(:task, :completed, teacher: @teacher, title: 'Done', due_date: Date.new(2026, 9, 2))
    end

    it 'completed=false returns only what is still open' do
      get api_v1_tasks_url, params: { completed: 'false' }
      expect(titles_in_response).to eq(%w[Overdue Soon Later Undated])
    end

    it 'completed=true returns only what is finished' do
      get api_v1_tasks_url, params: { completed: 'true' }
      expect(titles_in_response).to eq(['Done'])
    end

    it 'due_by is inclusive of the boundary date' do
      get api_v1_tasks_url, params: { due_by: '2026-09-20' }
      expect(titles_in_response).to contain_exactly('Overdue', 'Done', 'Soon')
    end

    it 'due_by leaves out undated tasks' do
      get api_v1_tasks_url, params: { due_by: '2027-01-01' }
      expect(titles_in_response).not_to include('Undated')
    end

    it 'serves the dashboard panel: open and due by a date' do
      get api_v1_tasks_url, params: { completed: 'false', due_by: '2026-09-20' }
      expect(titles_in_response).to eq(%w[Overdue Soon])
    end

    it 'serves the overdue question with the same two filters' do
      get api_v1_tasks_url, params: { completed: 'false', due_by: '2026-09-18' }
      expect(titles_in_response).to eq(['Overdue'])
    end

    it 'rejects a completed filter that is not a boolean' do
      get api_v1_tasks_url, params: { completed: 'banana' }
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']['details']['completed']).to include('must be true or false')
    end

    it 'rejects an unparseable due_by rather than ignoring it' do
      get api_v1_tasks_url, params: { due_by: 'soon-ish' }
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']['details']['due_by']).to include('must be a valid date')
    end

    it 'ignores a blank filter rather than erroring' do
      get api_v1_tasks_url, params: { completed: '', due_by: '' }
      expect(response).to have_http_status(:ok)
      expect(titles_in_response.length).to eq(5)
    end
  end

  describe 'repeating tasks' do
    def sign_in_teacher
      @teacher = FactoryBot.create(:teacher)
      sign_in(@teacher)
    end

    # Weekly on Fridays from 4 September 2026: 4, 11, 18, 25 September.
    def weekly_task(title: 'Submit reimbursement')
      task = FactoryBot.create(:task, teacher: @teacher, title: title, due_date: Date.new(2026, 9, 4))
      task.create_recurrence!(frequency: 'weekly', weekdays: [5])
      task.reload
    end

    def window
      { from: '2026-09-01', to: '2026-09-30' }
    end

    def listed
      JSON.parse(response.body)['data']
    end

    before { sign_in_teacher }

    describe 'expansion over the index' do
      it 'returns one entry per occurrence, each named by its date' do
        task = weekly_task
        get api_v1_tasks_url, params: window
        expect(listed.map { |row| row['due_date'] }).to eq(%w[2026-09-04 2026-09-11 2026-09-18 2026-09-25])
        expect(listed.map { |row| row['id'] }).to all(start_with("#{task.id}:"))
        expect(listed.map { |row| row['series_id'] }).to all(eq(task.id))
      end

      it 'returns an ordinary task whatever its due date, since only series are windowed' do
        FactoryBot.create(:task, teacher: @teacher, title: 'Far off', due_date: Date.new(2030, 1, 1))
        get api_v1_tasks_url, params: window
        expect(listed.map { |row| row['title'] }).to include('Far off')
      end
    end

    describe 'ticking one occurrence' do
      it 'marks that occurrence done and leaves the others alone' do
        task = weekly_task
        patch api_v1_task_url("#{task.id}:2026-09-11"), params: { completed: true }
        expect(response).to have_http_status(:ok)

        get api_v1_tasks_url, params: window
        expect(listed.map { |row| [row['due_date'], row['completed']] })
          .to eq([['2026-09-04', false], ['2026-09-11', true],
                  ['2026-09-18', false], ['2026-09-25', false]])
      end

      it 'records it as a row of its own rather than on the series' do
        task = weekly_task
        expect { patch api_v1_task_url("#{task.id}:2026-09-11"), params: { completed: true } }
          .to change(TaskCompletion, :count).by(1)
        expect(task.reload.completed_at).to be_nil
      end

      it 'unticking deletes the row again' do
        task = weekly_task
        patch api_v1_task_url("#{task.id}:2026-09-11"), params: { completed: true }
        expect { patch api_v1_task_url("#{task.id}:2026-09-11"), params: { completed: false } }
          .to change(TaskCompletion, :count).by(-1)

        get api_v1_tasks_url, params: window
        expect(listed.map { |row| row['completed'] }).to all(be(false))
      end

      it 'keeps the original time when ticked twice' do
        task = weekly_task
        patch api_v1_task_url("#{task.id}:2026-09-11"), params: { completed: true }
        first = TaskCompletion.sole.completed_at
        patch api_v1_task_url("#{task.id}:2026-09-11"), params: { completed: true }
        expect(TaskCompletion.sole.completed_at).to eq(first)
      end

      it 'leaves an ordinary task ticking its own column' do
        task = FactoryBot.create(:task, teacher: @teacher)
        patch api_v1_task_url(task), params: { completed: true }
        expect(task.reload.completed_at).to be_present
        expect(TaskCompletion.count).to eq(0)
      end

      it 'filters on the occurrence rather than the series' do
        task = weekly_task
        patch api_v1_task_url("#{task.id}:2026-09-11"), params: { completed: true }

        get api_v1_tasks_url, params: window.merge(completed: 'false')
        expect(listed.map { |row| row['due_date'] }).to eq(%w[2026-09-04 2026-09-18 2026-09-25])
        get api_v1_tasks_url, params: window.merge(completed: 'true')
        expect(listed.map { |row| row['due_date'] }).to eq(['2026-09-11'])
      end
    end

    describe 'the three edit modes' do
      it 'this occurrence detaches it and leaves the rest' do
        task = weekly_task
        patch api_v1_task_url("#{task.id}:2026-09-18"),
              params: { title: 'With receipts', scope: 'this' }
        expect(response).to have_http_status(:ok)

        get api_v1_tasks_url, params: window
        titles = listed.map { |row| [row['due_date'], row['title']] }
        expect(titles).to contain_exactly(
          ['2026-09-04', 'Submit reimbursement'], ['2026-09-11', 'Submit reimbursement'],
          ['2026-09-18', 'With receipts'], ['2026-09-25', 'Submit reimbursement']
        )
      end

      it 'this and future splits the series' do
        task = weekly_task
        patch api_v1_task_url("#{task.id}:2026-09-18"),
              params: { title: 'Submit online', scope: 'this_and_future' }

        get api_v1_tasks_url, params: window
        expect(listed.map { |row| [row['due_date'], row['title']] })
          .to eq([['2026-09-04', 'Submit reimbursement'], ['2026-09-11', 'Submit reimbursement'],
                  ['2026-09-18', 'Submit online'], ['2026-09-25', 'Submit online']])
      end

      it 'all rewrites every occurrence' do
        task = weekly_task
        patch api_v1_task_url("#{task.id}:2026-09-18"), params: { title: 'Renamed', scope: 'all' }

        get api_v1_tasks_url, params: window
        expect(listed.map { |row| row['title'] }).to all(eq('Renamed'))
      end

      it 'rejects a scope it does not know' do
        task = weekly_task
        patch api_v1_task_url("#{task.id}:2026-09-18"), params: { title: 'x', scope: 'sideways' }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe 'the two delete modes' do
      it 'this occurrence removes only that one' do
        task = weekly_task
        delete api_v1_task_url("#{task.id}:2026-09-11"), params: { scope: 'this' }
        expect(response).to have_http_status(:no_content)

        get api_v1_tasks_url, params: window
        expect(listed.map { |row| row['due_date'] }).to eq(%w[2026-09-04 2026-09-18 2026-09-25])
      end

      it 'this and future ends the series the day before' do
        task = weekly_task
        delete api_v1_task_url("#{task.id}:2026-09-18"), params: { scope: 'this_and_future' }

        get api_v1_tasks_url, params: window
        expect(listed.map { |row| row['due_date'] }).to eq(%w[2026-09-04 2026-09-11])
      end

      it 'all removes the whole series' do
        task = weekly_task
        expect { delete api_v1_task_url(task.id), params: { scope: 'all' } }
          .to change(Task, :count).by(-1)
      end
    end

    describe 'a rule needs something to repeat from' do
      it 'refuses a repeating task with no due date' do
        post api_v1_tasks_url, params: { title: 'Nowhere to start',
                                         recurrence: { frequency: 'daily' } }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'drops the ticks when a task stops repeating' do
        task = weekly_task
        patch api_v1_task_url("#{task.id}:2026-09-11"), params: { completed: true }
        expect { patch api_v1_task_url(task.id), params: { recurrence: '' } }
          .to change(TaskCompletion, :count).by(-1)
        expect(task.reload.recurrence).to be_nil
      end
    end
  end

  describe 'GET /api/v1/tasks/:id' do
    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        @task = FactoryBot.create(:task, teacher: @teacher, title: 'Export report cards')
        sign_in(@teacher)
      end

      it 'returns the task' do
        get api_v1_task_url(@task)
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['id']).to eq(@task.id)
      end

      it 'returns not found when the task does not exist' do
        get api_v1_task_url('00000000-0000-0000-0000-000000000000')
        expect(response).to have_http_status(:not_found)
      end

      it "returns not found for another teacher's task" do
        other = FactoryBot.create(:teacher)
        get api_v1_task_url(FactoryBot.create(:task, teacher: other))
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get api_v1_task_url(FactoryBot.create(:task))
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/tasks' do
    let(:valid_params) do
      { title: 'Submit internet reimbursement', description: 'Attach the September bill', due_date: '2026-09-30' }
    end

    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        sign_in(@teacher)
      end

      it 'returns created' do
        post api_v1_tasks_url, params: valid_params
        expect(response).to have_http_status(:created)
      end

      it 'creates a task for the teacher' do
        expect do
          post api_v1_tasks_url, params: valid_params
        end.to change(@teacher.tasks, :count).by(1)
      end

      it 'returns the created payload' do
        post api_v1_tasks_url, params: valid_params
        data = JSON.parse(response.body)['data']
        expect(data['title']).to eq('Submit internet reimbursement')
        expect(data['due_date']).to eq('2026-09-30')
        expect(data['completed']).to be(false)
        expect(data['completed_at']).to be_nil
      end

      it 'allows a minimal body of just a title' do
        post api_v1_tasks_url, params: { title: 'Email the co-op leader' }
        data = JSON.parse(response.body)['data']
        expect(response).to have_http_status(:created)
        expect(data['description']).to be_nil
        expect(data['due_date']).to be_nil
      end

      it 'can be created already complete' do
        post api_v1_tasks_url, params: valid_params.merge(completed: 'true')
        expect(JSON.parse(response.body)['data']['completed']).to be(true)
      end

      it 'ignores an injected teacher_id' do
        other = FactoryBot.create(:teacher)
        post api_v1_tasks_url, params: valid_params.merge(teacher_id: other.id)
        expect(JSON.parse(response.body)['data']['teacher_id']).to eq(@teacher.id)
      end

      it 'ignores an injected completed_at' do
        post api_v1_tasks_url, params: valid_params.merge(completed_at: '2020-01-01T00:00:00Z')
        expect(JSON.parse(response.body)['data']['completed_at']).to be_nil
      end

      it 'returns a validation error when the title is blank' do
        post api_v1_tasks_url, params: valid_params.merge(title: '')
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'allows a duplicate title' do
        FactoryBot.create(:task, teacher: @teacher, title: 'Submit internet reimbursement')
        post api_v1_tasks_url, params: valid_params
        expect(response).to have_http_status(:created)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        post api_v1_tasks_url, params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/tasks/:id' do
    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        @task = FactoryBot.create(:task, teacher: @teacher, title: 'Export report cards')
        sign_in(@teacher)
      end

      it 'updates the task' do
        patch api_v1_task_url(@task), params: { title: 'Export report cards for term one', due_date: '2026-10-15' }
        expect(response).to have_http_status(:ok)
        @task.reload
        expect(@task.title).to eq('Export report cards for term one')
        expect(@task.due_date).to eq(Date.new(2026, 10, 15))
      end

      it 'ticks the checkbox' do
        patch api_v1_task_url(@task), params: { completed: 'true' }
        expect(response).to have_http_status(:ok)
        expect(@task.reload.completed_at).to be_present
        expect(JSON.parse(response.body)['data']['completed']).to be(true)
      end

      it 'unticks the checkbox' do
        @task.update!(completed: true)
        patch api_v1_task_url(@task), params: { completed: 'false' }
        expect(@task.reload.completed_at).to be_nil
        expect(JSON.parse(response.body)['data']['completed']).to be(false)
      end

      it 'does not move the timestamp when ticked twice' do
        original = Time.utc(2026, 9, 1, 8, 0, 0)
        @task.update!(completed_at: original)
        patch api_v1_task_url(@task), params: { completed: 'true' }
        expect(@task.reload.completed_at).to eq(original)
      end

      it 'clears the description when sent blank' do
        patch api_v1_task_url(@task), params: { description: '' }
        expect(@task.reload.description).to be_nil
      end

      it 'clears the due date when sent blank' do
        patch api_v1_task_url(@task), params: { due_date: '' }
        expect(@task.reload.due_date).to be_nil
      end

      it 'returns a validation error when the title is blank' do
        patch api_v1_task_url(@task), params: { title: '' }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns not found for another teacher's task" do
        other = FactoryBot.create(:teacher)
        patch api_v1_task_url(FactoryBot.create(:task, teacher: other)), params: { title: 'Hijacked' }
        expect(response).to have_http_status(:not_found)
      end

      it "leaves another teacher's task untouched" do
        other = FactoryBot.create(:teacher)
        theirs = FactoryBot.create(:task, teacher: other, title: 'Theirs')
        patch api_v1_task_url(theirs), params: { title: 'Hijacked', completed: 'true' }
        theirs.reload
        expect(theirs.title).to eq('Theirs')
        expect(theirs.completed_at).to be_nil
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        patch api_v1_task_url(FactoryBot.create(:task)), params: { title: 'Nope' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/tasks/:id' do
    context 'when authenticated' do
      before do
        @teacher = FactoryBot.create(:teacher)
        @task = FactoryBot.create(:task, teacher: @teacher)
        sign_in(@teacher)
      end

      it 'returns no content' do
        delete api_v1_task_url(@task)
        expect(response).to have_http_status(:no_content)
      end

      it 'removes the row, unlike students and subjects' do
        expect do
          delete api_v1_task_url(@task)
        end.to change(Task, :count).by(-1)
      end

      it 'removes the task from the index' do
        delete api_v1_task_url(@task)
        get api_v1_tasks_url
        expect(JSON.parse(response.body)['data']).to be_empty
      end

      it "returns not found for another teacher's task" do
        other = FactoryBot.create(:teacher)
        delete api_v1_task_url(FactoryBot.create(:task, teacher: other))
        expect(response).to have_http_status(:not_found)
      end

      it "leaves another teacher's task in place" do
        other = FactoryBot.create(:teacher)
        theirs = FactoryBot.create(:task, teacher: other)
        expect { delete api_v1_task_url(theirs) }.not_to change(Task, :count)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        delete api_v1_task_url(FactoryBot.create(:task))
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'students and ownership' do
    def json_task
      JSON.parse(response.body)['data']
    end

    before do
      @teacher = FactoryBot.create(:teacher)
      @eliza = FactoryBot.create(:student, teacher: @teacher, first_name: 'Eliza')
      @samuel = FactoryBot.create(:student, teacher: @teacher, first_name: 'Samuel')
      sign_in(@teacher)
    end

    describe 'POST /api/v1/tasks' do
      it 'creates a teacher owned task naming a student' do
        post api_v1_tasks_url,
             params: { title: 'Export report cards', owned_by: 'teacher', student_ids: [@eliza.id] },
             as: :json

        expect(response).to have_http_status(:created)
        expect(json_task['owned_by']).to eq('teacher')
        expect(json_task['student_ids']).to eq([@eliza.id])
      end

      it 'creates a task naming several students' do
        post api_v1_tasks_url,
             params: { title: 'Tidy the schoolroom', owned_by: 'student',
                       student_ids: [@eliza.id, @samuel.id] },
             as: :json

        expect(response).to have_http_status(:created)
        expect(json_task['student_ids']).to contain_exactly(@eliza.id, @samuel.id)
      end

      it 'creates a task naming nobody' do
        post api_v1_tasks_url, params: { title: 'Pay the co-op dues' }, as: :json

        expect(response).to have_http_status(:created)
        expect(json_task['student_ids']).to eq([])
        expect(json_task['owned_by']).to eq('teacher')
      end

      it 'refuses a student owned task that names nobody' do
        post api_v1_tasks_url, params: { title: 'Science fair', owned_by: 'student' }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['error']['details']).to have_key('student_ids')
      end

      # The rule events already have: one id belonging to someone else rejects
      # the whole request rather than being quietly dropped from it.
      it 'refuses a real student id belonging to another teacher' do
        other_teacher = FactoryBot.create(:teacher, email: 'other@test.com')
        theirs = FactoryBot.create(:student, teacher: other_teacher, first_name: 'Noah')

        post api_v1_tasks_url,
             params: { title: 'Cross teacher', student_ids: [theirs.id] }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['error']['details']['student_ids'])
          .to include('must all belong to the current teacher')
      end

      it 'creates nothing when one of several ids belongs to another teacher' do
        other_teacher = FactoryBot.create(:teacher, email: 'other2@test.com')
        theirs = FactoryBot.create(:student, teacher: other_teacher, first_name: 'Noah')

        expect do
          post api_v1_tasks_url,
               params: { title: 'Partly mine', student_ids: [@eliza.id, theirs.id] }, as: :json
        end.not_to change(Task, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe 'PATCH /api/v1/tasks/:id' do
      it 'replaces the student set outright' do
        task = FactoryBot.create(:task, teacher: @teacher, students: [@eliza])

        patch api_v1_task_url(task), params: { student_ids: [@samuel.id] }, as: :json

        expect(json_task['student_ids']).to eq([@samuel.id])
      end

      it 'leaves the students alone when none are submitted' do
        task = FactoryBot.create(:task, teacher: @teacher, students: [@eliza])

        patch api_v1_task_url(task), params: { title: 'Renamed' }, as: :json

        expect(json_task['student_ids']).to eq([@eliza.id])
      end

      it 'clears the students of a teacher owned task with an empty array' do
        task = FactoryBot.create(:task, teacher: @teacher, students: [@eliza])

        patch api_v1_task_url(task), params: { student_ids: [] }, as: :json

        expect(json_task['student_ids']).to eq([])
      end

      # Refused rather than quietly handed back to the teacher: which of the
      # two was meant is not something the server can know.
      it 'refuses to take the last student off a task that is a student\'s' do
        task = FactoryBot.create(:task, teacher: @teacher, owned_by: 'student', students: [@eliza])

        patch api_v1_task_url(task), params: { student_ids: [] }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(task.reload.student_ids).to eq([@eliza.id])
      end

      it 'allows the last student off in the same request that hands it back' do
        task = FactoryBot.create(:task, teacher: @teacher, owned_by: 'student', students: [@eliza])

        patch api_v1_task_url(task),
              params: { owned_by: 'teacher', student_ids: [] }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_task['student_ids']).to eq([])
      end

      it 'refuses making a task a student\'s while it names nobody' do
        task = FactoryBot.create(:task, teacher: @teacher)

        patch api_v1_task_url(task), params: { owned_by: 'student' }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'refuses a real student id belonging to another teacher' do
        other_teacher = FactoryBot.create(:teacher, email: 'other3@test.com')
        theirs = FactoryBot.create(:student, teacher: other_teacher, first_name: 'Noah')
        task = FactoryBot.create(:task, teacher: @teacher, students: [@eliza])

        patch api_v1_task_url(task), params: { student_ids: [theirs.id] }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(task.reload.student_ids).to eq([@eliza.id])
      end
    end

    describe 'GET /api/v1/tasks' do
      it 'sends the students and the owner on each task' do
        FactoryBot.create(:task, teacher: @teacher, owned_by: 'both', students: [@eliza, @samuel])

        get api_v1_tasks_url

        task = JSON.parse(response.body)['data'].first
        expect(task['owned_by']).to eq('both')
        expect(task['student_ids']).to contain_exactly(@eliza.id, @samuel.id)
      end
    end
  end
end
