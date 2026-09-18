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
end
