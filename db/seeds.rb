# frozen_string_literal: true

# Demo and test data: ten teachers covering the states the app can be in.
#
# WARNING: every account created here uses the same weak password, password123,
# and the emails are predictable. These accounts must be removed before real
# user data is in production.
#
# Idempotent by ownership. The seed owns exactly ten accounts, teacher1@test.com
# through teacher10@test.com. Each run finds or creates those ten by email, then
# destroys and rebuilds their students and events, so a second run produces the
# same data rather than a second copy of it. Nothing outside those ten accounts
# is read or written.
#
# Every date is relative to the run date. The anchor is the first of the current
# month, so a run in March lays out a March calendar and a later run in June
# moves the whole set to June. Teacher 6 sits two months back, teacher 7 a month
# ahead, and both move with it.

PASSWORD = 'password123'
ANCHOR = Date.current.beginning_of_month

# The palette the web client offers when a parent picks a student colour.
COLORS = %w[
  #d97b0a #dc2626 #16a34a #0d9488 #2563eb #7c3aed #db2777
  #475569 #bc5b22 #7a322d #c08b26 #67482c #796123
].freeze

GRADE_LEVELS = %w[pre-k kindergarten 1 2 3 4 5 6 7 8 9 10 11 12].freeze

SUBJECTS = [
  'Math', 'Phonics', 'Handwriting', 'Science', 'History', 'Literature',
  'Spelling', 'Geography', 'Latin', 'Art', 'Music Theory', 'Nature Study',
  'Copywork', 'Recitation', 'Logic', 'Typing', 'Biology', 'Algebra',
  'Geometry', 'Composition', 'Read Aloud', 'Bible'
].freeze

ACTIVITIES = [
  ['Co-op meetup', 'Fellowship hall'],
  ['Library trip', 'Public library'],
  ['Piano lesson', "Ms. Danner's studio"],
  ['Soccer practice', 'Riverside Park'],
  ['Swim lessons', 'Community center pool'],
  ['Field trip: science museum', 'Museum of Science'],
  ['Park day', 'Riverside Park'],
  ['4-H meeting', 'County extension office'],
  ['Choir rehearsal', 'Grace Chapel'],
  ['Nature walk', 'Creek trail'],
  ['Farm visit', 'Willow Creek Farm'],
  ['Robotics club', 'Community center'],
  ['Chess club', 'Public library'],
  ['Scouts', 'Fellowship hall']
].freeze

ALL_DAY_EVENTS = [
  ['Standardized testing day', 'No regular lessons today.'],
  ['Co-op field day', 'Packed lunches and water bottles.'],
  ['Family day: no school', nil],
  ['Grandparents visiting', nil]
].freeze

# Most events carry no note, so the nils are load bearing.
NOTES = [
  'Bring the workbook and a sharpened pencil.',
  'Pick up where we left off in chapter four.',
  'Review last week before starting the new unit.',
  'Snacks are covered this week.',
  nil, nil, nil
].freeze

SEED_EMAILS = (1..10).map { |n| "teacher#{n}@test.com" }.freeze

# Times are built in the teacher's own zone and stored as UTC, which is what the
# clients send and what the range queries compare against.
def local_time(zone, date, hour, minute = 0)
  ActiveSupport::TimeZone[zone].local(date.year, date.month, date.day, hour, minute).utc
end

# Finds or creates one demo account by email, then clears its students and
# events so the rest of the run rebuilds them from scratch.
def demo_teacher(email:, first_name:, last_name:, time_zone: Teacher::DEFAULT_TIME_ZONE)
  teacher = Teacher.find_or_initialize_by(email: email)
  teacher.assign_attributes(
    first_name: first_name,
    last_name: last_name,
    time_zone: time_zone,
    onboarding_completed: true,
    email_verified_at: teacher.email_verified_at || Time.current,
    is_active: true
  )
  teacher.password = PASSWORD
  teacher.save!

  teacher.calendar_events.destroy_all
  # Before the subjects and students they hang off: destroying a subject takes
  # its assignments with it either way, but doing it in this order keeps the
  # rebuild readable rather than relying on the cascade.
  teacher.assignments.destroy_all
  # Types go with them and are rebuilt from scratch, so a second run starts
  # from the three built in ones at their starting weight rather than from
  # whatever the last run left behind.
  teacher.assignment_types.destroy_all
  AssignmentType.create_built_ins_for(teacher)
  teacher.students.destroy_all
  teacher.tasks.destroy_all
  # Before the subjects their entries point at, and before the students they
  # belong to, so a rebuild starts from nothing rather than from half a card.
  teacher.report_cards.destroy_all
  teacher.subjects.destroy_all
  teacher
end

def add_student(teacher, first_name, last_name, grade_index, color_index, active: true, middle_name: nil)
  teacher.students.create!(
    first_name: first_name,
    middle_name: middle_name,
    last_name: last_name,
    grade_level: GRADE_LEVELS[grade_index % GRADE_LEVELS.length],
    color: COLORS[color_index % COLORS.length],
    is_active: active
  )
end

# Colours come from the same palette the students use, so a subject and a
# student pick from one list.
def add_subject(teacher, name, color_index, description = nil)
  teacher.subjects.create!(
    name: name,
    color: COLORS[color_index % COLORS.length],
    description: description
  )
end

# due is a Date or nil, and done_days_ago marks the task complete that many days
# back. Both are relative to the run date, so the states this seeds keep meaning
# the same thing whenever it is run.
#
# students names who the task concerns and owned_by says whose job it is. The
# two are separate on purpose: "Print the reading log" names Ruth and is the
# teacher's work, while "Finish the science fair project" names Eliza and is
# hers. A task that is a student's has to name at least one.
def add_task(teacher, title:, due: nil, notes: nil, done_days_ago: nil, students: [], owned_by: 'teacher')
  teacher.tasks.create!(
    title: title,
    description: notes,
    due_date: due,
    completed_at: done_days_ago && (Date.current - done_days_ago).to_time,
    owned_by: owned_by,
    students: Array(students)
  )
end

# scores maps a student to what they earned. nil is work the student holds but
# that has not been marked yet, which stays out of every average; 0 is a real
# zero that counts against one. A student left out of the hash is not given the
# work at all, and an empty hash is an assignment set but not yet handed out.
#
# weight is how much the work counts next to other work in the same subject: 1
# is ordinary, 2 counts double, 0 keeps it off the average altogether. Passing
# it the same number as the type's default leaves the assignment inheriting;
# passing a different one records it as the teacher's own choice, which is what
# keeps a later change to that default from moving it.
#
# type is the kind of work. Left out, it is the ordinary Assignment, which is
# what everything set before types existed is.
#
# A score may be a number or a letter. A letter goes in the way a teacher
# entering one does, so the seeded rows carry the same provenance hers do.
def add_assignment(teacher, subject:, title:, due: nil, points: 100, weight: 1, notes: nil,
                   type: nil, scores: {})
  assignment = teacher.assignments.build(
    subject: subject, title: title, description: notes, due_date: due,
    points_possible: points, assignment_type: type || built_in_type(teacher, 'Assignment')
  )

  # Whether a weight is the teacher's own is a decision the app records rather
  # than infers, so the seed has to make it. Here a weight that differs from
  # the type's default is one she chose, which is the story this fixture is
  # telling: it is a statement about the demo data, not a rule of the system.
  if weight == assignment.assignment_type.default_weight
    assignment.inherit_weight!
  else
    assignment.override_weight!(weight)
  end
  assignment.save!

  scores.each { |student, earned| record_score(assignment, student, earned) }

  assignment
end

def built_in_type(teacher, name)
  teacher.assignment_types.find_by(name: name, is_built_in: true)
end

def add_assignment_type(teacher, name:, weight: 1)
  teacher.assignment_types.create!(name: name, default_weight: weight, is_built_in: false)
end

# Changes what a kind of work counts by default. Seeded through the same
# service the endpoint uses, so the seeded state is one a teacher could have
# reached by clicking.
def set_type_default(teacher, name, weight, mode: 'all', from_date: nil)
  type = teacher.assignment_types.find_by(name: name)
  AssignmentTypeDefaultWeight.call(type: type, weight: weight, mode: mode, from_date: from_date)
  type
end

def record_score(assignment, student, earned)
  grade = assignment.assignment_grades.build(student: student)

  if earned.is_a?(String)
    grade.apply_letter(earned)
  else
    grade.points_earned = earned
  end

  grade.save!
end

# A report card: a saved copy of one student's grades for a period.
#
# issued freezes it. A draft is left unissued, and its grades keep following
# the marking, which is what a teacher is looking at while she writes one.
#
# overrides maps a subject to the letter she issued instead of the calculated
# one, optionally with a reason. The calculated grade is kept either way, so
# the card can show what the override replaced.
def add_report_card(teacher, student:, title:, from:, to:, comments: nil, issued: false,
                    overall_override: nil, overall_reason: nil, overrides: {}, subject_comments: {})
  card = teacher.report_cards.create!(
    student: student, title: title, period_start: from, period_end: to, comments: comments,
    group_id: SecureRandom.uuid, version: 1,
    overall_override_letter: overall_override, overall_override_reason: overall_reason
  )

  apply_card_entries(card, overrides, subject_comments)
  ReportCardSnapshot.call(card) if issued
  card
end

# Her words and her overrides, stored before any snapshot is taken so an
# issued card carries them too.
def apply_card_entries(card, overrides, subject_comments)
  (overrides.keys | subject_comments.keys).each do |subject|
    entry = card.report_card_entries.find_or_initialize_by(subject_id: subject.id)
    entry.subject_name = subject.name
    letter, reason = Array(overrides[subject])
    entry.override_letter = letter
    entry.override_reason = reason
    entry.comments = subject_comments[subject]
    entry.save!
  end
end

# The next version of an issued card, through the same service the endpoint
# uses, so the seeded history is one a teacher could have produced by clicking.
def revise_report_card(card, title: nil, comments: nil, issued: false, overrides: {})
  copy = ReportCardVersion.call(card)
  copy.title = title if title
  copy.comments = comments if comments
  copy.save!
  apply_card_entries(copy, overrides, {})
  # Issuing a version re-snapshots from current grades, which is the point of
  # reissuing after a correction.
  ReportCardSnapshot.call(copy) if issued
  copy
end

# hour is [hour, minute] in the teacher's zone, or nil for an all day event.
def add_event(teacher, title:, date:, hour: nil, minutes: 60, students: [], location: nil, notes: nil)
  zone = teacher.effective_time_zone

  start_time, end_time =
    if hour.nil?
      [local_time(zone, date, 0, 0), local_time(zone, date, 23, 59)]
    else
      start_at = local_time(zone, date, hour[0], hour[1])
      [start_at, start_at + minutes.minutes]
    end

  event = teacher.calendar_events.create!(
    title: title, notes: notes, location: location,
    start_time: start_time, end_time: end_time,
    all_day: hour.nil?, created_time_zone: zone
  )
  Array(students).each { |student| event.students << student }
  event
end

# A repeating event or task: one row carrying a rule, expanded on read. The
# same helper serves both, because the rule is the same rule: only what an
# occurrence is made of differs, and that is the owner's business rather than
# the rule's. weekdays are 0 for Sunday through 6 for Saturday, and are only
# read for a weekly series.
def repeat(record, frequency:, weekdays: [], monthly_anchor: nil, until_date: nil)
  record.create_recurrence!(
    frequency: frequency, weekdays: weekdays,
    monthly_anchor: monthly_anchor, until_date: until_date
  )
  record
end

# One occurrence of a repeating task ticked off. A series has no row per
# occurrence, so the tick names the date: this week being done says nothing
# about next week.
def tick_occurrence(task, date, done_days_ago: 0)
  task.task_completions.create!(
    occurrence_date: date, completed_at: (Date.current - done_days_ago).to_time
  )
end

# One occurrence of a repeating task edited: it becomes a standalone task, and
# the series records that the date is taken so the rule does not produce it
# twice.
def edit_task_occurrence(task, date, **overrides)
  replacement = task.teacher.tasks.create!(
    task.slice(:title, :description, :owned_by)
        .merge('due_date' => date)
        .merge(overrides.transform_keys(&:to_s))
        .merge('students' => task.students.to_a)
  )
  task.recurrence.recurrence_exceptions.create!(occurrence_date: date, replacement_id: replacement.id)
  replacement
end

# One occurrence taken out of a series: the rule still produces the rest.
def skip_occurrence(event, date)
  event.recurrence.recurrence_exceptions.create!(occurrence_date: date)
end

# One occurrence edited: it becomes a standalone event, and the series records
# that the date is taken so the rule does not produce it twice.
def edit_occurrence(event, date, **overrides)
  replacement = event.teacher.calendar_events.create!(
    event.slice(:title, :notes, :location, :all_day, :created_time_zone)
         .merge('start_time' => event.start_time, 'end_time' => event.end_time)
         .merge(overrides.transform_keys(&:to_s))
  )
  replacement.students << event.students
  event.recurrence.recurrence_exceptions.create!(occurrence_date: date, replacement_id: replacement.id)
  replacement
end

# The most recent given weekday on or before today, which is the anchor a
# weekly series wants: the series then has occurrences already behind it to
# have been ticked, and more ahead of it still to do.
def last_weekday(wday)
  Date.current - ((Date.current.wday - wday) % 7)
end

# The nth occurrence of a weekday in a month: nth_weekday_of(month, 5, 2) is
# the second Friday, which is the anchor a monthly by position series needs.
def nth_weekday_of(month, wday, position)
  first = Date.new(month.year, month.month, 1)
  first + ((wday - first.wday) % 7) + ((position - 1) * 7)
end

# The nth weekday of the anchored month, counting from zero. Lessons land on
# school days rather than scattering across weekends.
def weekday(offset)
  date = ANCHOR
  found = 0
  loop do
    return date if date.on_weekday? && (found += 1) > offset

    date += 1
  end
end

ActiveRecord::Base.transaction do
  # 1: a typical family. Four students on the roster and one removed, a month of
  # ordinary lessons and activities, timed and all day mixed, a few events with
  # nobody attached.
  one = demo_teacher(email: 'teacher1@test.com', first_name: 'Hannah', last_name: 'Whitfield')
  whitfields = [
    add_student(one, 'Eliza', 'Whitfield', 5, 0),
    add_student(one, 'Samuel', 'Whitfield', 3, 4),
    add_student(one, 'Ruth', 'Whitfield', 1, 3),
    add_student(one, 'Isaac', 'Whitfield', 0, 6)
  ]
  # Off the roster but still on her old events: this is the record behind the
  # "Former student" pill.
  departed = add_student(one, 'Naomi', 'Whitfield', 8, 9, active: false)

  20.times do |index|
    add_event(
      one,
      title: SUBJECTS[index % SUBJECTS.length],
      date: weekday(index),
      hour: [[8, 30], [9, 0], [9, 30]][index % 3],
      minutes: 45,
      students: whitfields.sample(1 + (index % 3)),
      location: index.even? ? 'Kitchen table' : 'Home classroom',
      notes: NOTES[index % NOTES.length]
    )
  end

  8.times do |index|
    title, location = ACTIVITIES[index % ACTIVITIES.length]
    add_event(
      one, title: title, date: weekday((index * 2) + 1),
      hour: [[15, 30], [16, 0], [18, 0]][index % 3], minutes: 90,
      students: index.zero? ? [] : whitfields.sample(2), location: location
    )
  end

  ALL_DAY_EVENTS.first(3).each_with_index do |(title, notes), index|
    add_event(one, title: title, date: weekday(3 + (index * 6)), students: whitfields, notes: notes)
  end

  add_event(one, title: 'Piano recital', date: weekday(12), hour: [17, 0], minutes: 120,
                 students: [departed, whitfields[0]], location: 'Grace Chapel',
                 notes: 'Naomi is accompanying her sister.')

  # Her repeating timetable, and the reference set for how a series behaves.
  #
  # Two days at once, so Tuesday and Thursday Latin is one series rather than
  # two. No end date: it simply keeps going, which is what a timetable does.
  latin = repeat(
    add_event(one, title: 'Latin drill', date: ANCHOR, hour: [9, 0], minutes: 30,
                   students: whitfields.first(2), location: 'Kitchen table'),
    frequency: 'weekly', weekdays: [2, 4]
  )
  # One week it moved to the afternoon: an edited occurrence is a standalone
  # event, and the series stops producing that date.
  #
  # Both dates are picked by weekday rather than by an offset from the anchor.
  # An exception only means anything on a date the rule actually produces, and
  # a fixed offset lands on the right weekday only in the months where the
  # anchor happens to fall on one.
  latin_moved = nth_weekday_of(ANCHOR, 2, 3)
  edit_occurrence(latin, latin_moved, title: 'Latin drill, moved to the afternoon',
                         start_time: local_time(one.effective_time_zone, latin_moved, 15, 0),
                         end_time: local_time(one.effective_time_zone, latin_moved, 15, 30))
  # Another week it did not happen at all.
  skip_occurrence(latin, nth_weekday_of(ANCHOR, 4, 3))

  # The same weekday position each month rather than the same date: the co-op
  # meets on the second Friday, whichever date that falls on.
  repeat(
    add_event(one, title: 'Co-op morning', date: nth_weekday_of(ANCHOR, 5, 2), hour: [10, 0],
                   minutes: 180, students: whitfields, location: 'Grace Chapel'),
    frequency: 'monthly', monthly_anchor: 'weekday_position'
  )

  # A series that has ended: swimming ran weekly through the summer and stopped.
  # Named for the term it ran in, so it is not confused with the one off swim
  # lesson on the activities list: an ended series is worth being able to find.
  repeat(
    add_event(one, title: 'Summer swim lessons', date: ANCHOR - 60, hour: [16, 0], minutes: 45,
                   students: whitfields.last(2), location: 'Community pool'),
    frequency: 'weekly', weekdays: [3], until_date: ANCHOR - 7
  )

  # Every day, with an end in sight: the read aloud runs to the end of term.
  repeat(
    add_event(one, title: 'Morning read aloud', date: ANCHOR, hour: [8, 0], minutes: 20,
                   students: whitfields, location: 'Living room'),
    frequency: 'daily', until_date: ANCHOR + 90
  )

  # Once a year, and all day: the fourth frequency the rule supports, on the
  # one kind of entry a family actually repeats annually.
  repeat(
    add_event(one, title: "Eliza's birthday", date: ANCHOR + 3, students: [whitfields[0]],
                   notes: 'No lessons after lunch.'),
    frequency: 'yearly'
  )

  # A full classical spread, one colour each from the shared palette.
  one_math = add_subject(one, 'Math', 0, 'Arithmetic, algebra and problem solving')
  one_english = add_subject(one, 'Language Arts', 4, 'Reading, spelling, grammar and composition')
  one_science = add_subject(one, 'Science', 2, 'Nature study, biology and the scientific method')
  one_history = add_subject(one, 'History', 9, 'Ancients through to the modern era')
  one_latin = add_subject(one, 'Latin', 5)
  one_art = add_subject(one, 'Art', 6, 'Drawing, painting and picture study')
  one_music = add_subject(one, 'Music', 3)
  one_bible = add_subject(one, 'Bible', 11, 'Memory work and family study')

  # Her mark book, and the reference set for the grades UI: every state it has
  # to draw is here. Eliza and Samuel carry most of the work, Ruth has the
  # three pieces a kindergartener gets, and Isaac has none at all, which is
  # what a progress report with nothing in it looks like.
  eliza, samuel, ruth = whitfields

  # Hannah teaches in the Charlotte Mason way, so she has a kind of work the
  # built in three do not name, and she has it counting double.
  one_narration = add_assignment_type(one, name: 'Narration', weight: 2)
  # A built in type moved off its starting weight: tests count triple in this
  # house, and every test she sets from now on inherits that.
  set_type_default(one, 'Test', 3)
  one_test = built_in_type(one, 'Test')
  one_quiz = built_in_type(one, 'Quiz')

  # Fully marked, ordinary weight: the plain case.
  add_assignment(one, subject: one_math, title: 'Chapter 4 problems', due: weekday(2),
                      points: 20, weight: 1, notes: 'Odd numbered questions only.',
                      scores: { eliza => 18, samuel => 15 })
  # Half weight on a Quiz, whose default is 1: a weight she set on this one
  # piece of work, so changing what quizzes count will not move it.
  add_assignment(one, subject: one_math, title: 'Times tables check', due: weekday(6),
                      points: 10, weight: 0.5, type: one_quiz,
                      scores: { eliza => 10, samuel => 7 })
  # Triple weight inherited from Test rather than typed: the figure a teacher
  # most needs the counts beside, since the heaviest piece is the one still
  # outstanding.
  add_assignment(one, subject: one_math, title: 'Unit 2 test', due: weekday(12),
                      points: 50, weight: 3, type: one_test,
                      scores: { eliza => 44, samuel => nil })

  # Marked by letter rather than by percentage: the row that has to show the
  # letter she chose when she opens it again.
  add_assignment(one, subject: one_english, title: 'Spelling list 3', due: weekday(3),
                      points: 15, weight: 1, scores: { eliza => 'A', samuel => 'B', ruth => 'C' })
  add_assignment(one, subject: one_english, title: "Narration: Pilgrim's Progress",
                      due: weekday(9), points: 10, weight: 2, type: one_narration,
                      notes: 'Told back in her own words, written down for her.',
                      scores: { eliza => 'A', samuel => nil })
  # Zero weight: handed out and marked, deliberately kept off the average.
  add_assignment(one, subject: one_english, title: 'Copywork week 2', due: weekday(14),
                      points: 5, weight: 0, notes: 'Practice only, not counted.',
                      scores: { eliza => 5, samuel => 4, ruth => 3 })

  # An explicit zero next to a real mark: the pair that has to read differently
  # from an unmarked box.
  add_assignment(one, subject: one_science, title: 'Nature journal entry', due: weekday(5),
                      points: 10, weight: 1, scores: { eliza => 8, samuel => 0 })
  # Nothing marked at all: set, handed out, and still waiting.
  add_assignment(one, subject: one_science, title: 'Leaf classification lab', due: weekday(11),
                      points: 25, weight: 2, scores: { eliza => nil, samuel => nil })

  add_assignment(one, subject: one_history, title: 'Ancient Egypt timeline', due: weekday(8),
                      points: 30, weight: 2, scores: { eliza => 27, samuel => 21 })
  # Inherits the Quiz default of 1, so it is the pair to the times tables check
  # above: same type, one following the default and one not.
  add_assignment(one, subject: one_latin, title: 'First declension quiz', due: weekday(4),
                      points: 20, weight: 1, type: one_quiz, scores: { eliza => 'B' })
  add_assignment(one, subject: one_art, title: 'Picture study: sunflowers', due: weekday(16),
                      points: 10, weight: 0, scores: { ruth => nil })

  # No due date: work that belongs to no report period, so it shows on the list
  # and in no progress figure.
  add_assignment(one, subject: one_bible, title: 'Memory work: Psalm 23',
                      points: 5, weight: 1, scores: { eliza => 5, samuel => 5, ruth => 5 })
  # Set but given to nobody yet: the row that has no marking to report.
  add_assignment(one, subject: one_music, title: 'Recital piece rehearsal log',
                      due: weekday(18), points: 10, weight: 1)

  # Her to-do list, covering every state the tasks UI has to draw: two already
  # late, one due today, two coming up, one with no date at all, and two ticked
  # off. Offsets from the run date, so the list means the same thing whenever
  # the seed runs.
  # Her own admin, naming nobody: the plain case tasks have always been.
  add_task(one, title: 'Submit internet reimbursement', due: Date.current - 5,
                notes: 'Attach the September bill and the enrolment letter.')
  add_task(one, title: 'Email co-op leader for winter schedule', due: Date.current,
                notes: 'Ask whether the January start moved.')
  add_task(one, title: 'Order printer ink and lined paper', due: Date.current + 2)
  add_task(one, title: 'Sort the curriculum shelf by subject')
  add_task(one, title: 'Renew the zoo membership', due: Date.current - 7, done_days_ago: 3)

  # Hers to do, about them: the pair that names students without handing the
  # work over, which is the distinction owned_by exists to record.
  add_task(one, title: 'Book the science museum field trip', due: Date.current + 6,
                notes: 'Group rate needs ten days notice.', students: whitfields)
  add_task(one, title: 'Print the reading log for October', done_days_ago: 1,
                students: [ruth])
  add_task(one, title: 'Order Eliza a new recorder', due: Date.current + 9,
                students: [eliza])

  # Theirs to do.
  add_task(one, title: 'Finish the science fair project', due: Date.current + 4,
                notes: 'Poster board and the write up, not the experiment itself.',
                students: [eliza], owned_by: 'student')
  add_task(one, title: 'Practise the recital piece', due: Date.current + 1,
                students: [ruth], owned_by: 'student')
  # Several students on one piece of work.
  add_task(one, title: 'Tidy the schoolroom shelves', due: Date.current - 1,
                students: [eliza, samuel, ruth], owned_by: 'student')
  add_task(one, title: 'Learn the Latin chant for Friday', due: Date.current + 3,
                students: [eliza, samuel], owned_by: 'student', done_days_ago: nil)

  # Shared: she sits with him for it, so neither of them owns it alone.
  add_task(one, title: 'Return the library books', due: Date.current - 2,
                students: [samuel], owned_by: 'both')
  add_task(one, title: 'Read one chapter a night', students: [samuel], owned_by: 'both')

  # Her report cards: one of every state the feature has.
  #
  # An issued card for the term that finished, frozen, so rescoring anything
  # inside it afterwards leaves it alone. Eliza's Latin was stronger than the
  # quiz average showed, so that line is overridden with the reason on it.
  eliza_autumn = add_report_card(
    one, student: eliza, title: 'Autumn term', from: ANCHOR - 60, to: ANCHOR - 1,
    comments: 'A steady term. Reading has come on a long way since September.',
    issued: true,
    overrides: { one_latin => ['A', 'Recitation and sight reading well beyond the quiz scores'] },
    subject_comments: { one_math => 'Times tables are secure now.' }
  )

  # The same card reissued: a second version, with the first still readable
  # beside it. This is what editing an issued card produces.
  revise_report_card(
    eliza_autumn, title: 'Autumn term, revised',
    comments: 'A steady term. Reading has come on a long way since September. ' \
              'Corrected after remarking the unit test.',
    issued: true
  )

  # A draft for the term that is running: its grades follow her marking and
  # keep moving until she issues it.
  add_report_card(
    one, student: samuel, title: 'Winter term so far', from: ANCHOR, to: Date.current,
    comments: 'Written up to today. Not final.'
  )

  # Her repeating to-dos, and the reference set for how a task series behaves.
  #
  # Weekly, with one week already ticked and the rest still open: a tick names
  # the date it belongs to, so this Friday being done says nothing about next.
  reimbursement = repeat(
    add_task(one, title: 'Submit the internet reimbursement', due: last_weekday(5),
                  notes: 'Attach the bill and the enrolment letter.'),
    frequency: 'weekly', weekdays: [5]
  )
  tick_occurrence(reimbursement, last_weekday(5), done_days_ago: 1)
  # One week it needed doing differently, and another it did not need doing at
  # all: an edited occurrence is a standalone task, a skipped one is simply
  # gone, and the rest of the series is untouched by either.
  edit_task_occurrence(reimbursement, last_weekday(5) + 7,
                       title: 'Submit the internet reimbursement with the new bill')
  skip_occurrence(reimbursement, last_weekday(5) + 14)

  # The same weekday position each month rather than the same date: the co-op
  # dues are due on the first Monday, whichever date that lands on. The months
  # with no such position simply have no occurrence rather than the task
  # sliding into a week nobody picked.
  repeat(
    add_task(one, title: 'Pay the co-op dues', due: nth_weekday_of(ANCHOR, 1, 1),
                  notes: 'First Monday, before the morning session.'),
    frequency: 'monthly', monthly_anchor: 'weekday_position'
  )

  # Daily with an end in sight, and a student's rather than the teacher's.
  repeat(
    add_task(one, title: 'Practise the piano for twenty minutes', due: Date.current,
                  students: [eliza], owned_by: 'student'),
    frequency: 'daily', until_date: Date.current + 45
  )

  # Monthly on the same date, which is the other monthly anchor.
  repeat(
    add_task(one, title: 'Back up the school records', due: Date.current + 3),
    frequency: 'monthly', monthly_anchor: 'day_of_month'
  )

  # 2: a heavy user. Ten students and a dense month, with one day loaded well
  # past the month grid's pill cap and the week column's scroll height.
  two = demo_teacher(email: 'teacher2@test.com', first_name: 'Marcus', last_name: 'Alderman')
  aldermans = [
    ['Josiah', 11], ['Abigail', 9], ['Levi', 7], ['Miriam', 6], ['Caleb', 5],
    ['Phoebe', 4], ['Silas', 3], ['Tabitha', 2], ['Ezra', 1], ['Junia', 0]
  ].each_with_index.map { |(name, grade), index| add_student(two, name, 'Alderman', grade, index) }

  (0..21).each do |day_offset|
    date = weekday(day_offset)
    next unless date.month == ANCHOR.month

    aldermans.each_with_index do |student, student_index|
      (student_index < 5 ? 2 : 1).times do |slot|
        add_event(
          two,
          title: SUBJECTS[(day_offset + student_index + slot) % SUBJECTS.length],
          date: date, hour: [8 + ((student_index + (slot * 5)) % 9), slot.zero? ? 0 : 30],
          minutes: 40, students: [student], location: 'Home classroom',
          notes: NOTES[(day_offset + student_index) % NOTES.length]
        )
      end
    end
  end

  # One deliberately overloaded day, on top of that day's regular lessons.
  heavy_day = weekday(9)
  22.times do |index|
    add_event(
      two, title: "#{SUBJECTS[index % SUBJECTS.length]} block #{index + 1}",
      date: heavy_day, hour: [7 + (index / 2), index.even? ? 0 : 30],
      minutes: 25, students: [aldermans[index % aldermans.length]], location: 'Home classroom'
    )
  end

  anselm = add_student(two, 'Anselm', 'Alderman', 10, 11, active: false)
  add_event(two, title: 'Regional debate tournament', date: weekday(14), hour: [9, 0],
                 minutes: 300, students: [anselm, aldermans[0]], location: 'Northside High School')

  # A ten child household runs on a timetable, so the busy account carries the
  # same repeating shapes the small one does, at its own scale. All four
  # frequencies, both monthly anchors, an ended series, and an occurrence moved
  # and another dropped.
  assembly = repeat(
    add_event(two, title: 'Morning assembly', date: ANCHOR, hour: [8, 0], minutes: 20,
                   students: aldermans, location: 'Home classroom',
                   notes: 'Hymn, memory verse, and the day read out.'),
    frequency: 'weekly', weekdays: [1, 3, 5]
  )
  # One morning it ran long and moved; another it was dropped for a trip. Both
  # dates are Wednesdays picked by position, so they are occurrences the rule
  # really produces whatever weekday the month starts on.
  assembly_long = nth_weekday_of(ANCHOR, 3, 2)
  edit_occurrence(assembly, assembly_long, title: 'Morning assembly, extended for prize giving',
                            start_time: local_time(two.effective_time_zone, assembly_long, 8, 0),
                            end_time: local_time(two.effective_time_zone, assembly_long, 9, 30))
  skip_occurrence(assembly, nth_weekday_of(ANCHOR, 3, 3))

  # The same weekday position each month: the co-op runs on the first Friday.
  repeat(
    add_event(two, title: 'Co-op teaching day', date: nth_weekday_of(ANCHOR, 5, 1), hour: [9, 30],
                   minutes: 240, students: aldermans, location: 'Fellowship hall'),
    frequency: 'monthly', monthly_anchor: 'weekday_position'
  )

  # The same date each month rather than the same weekday: book club is always
  # the fifteenth, whichever day that lands on.
  repeat(
    add_event(two, title: 'Family book club', date: Date.new(ANCHOR.year, ANCHOR.month, 15),
                   hour: [19, 0], minutes: 60, students: aldermans.first(6), location: 'Living room'),
    frequency: 'monthly', monthly_anchor: 'day_of_month'
  )

  # Once a year, all day: the anniversary of the day they started home schooling.
  repeat(
    add_event(two, title: 'First day of school anniversary', date: ANCHOR + 5, students: aldermans),
    frequency: 'yearly'
  )

  # A series that has finished: swimming ran through the summer and stopped.
  repeat(
    add_event(two, title: 'Swim term', date: ANCHOR - 70, hour: [16, 30], minutes: 45,
                   students: aldermans.last(5), location: 'Community center pool'),
    frequency: 'weekly', weekdays: [2], until_date: ANCHOR - 14
  )

  # All day entries, and one with nobody on it: a planning day is the teacher's
  # own, which is what an event with no attendees looks like.
  ALL_DAY_EVENTS.first(2).each_with_index do |(title, note), index|
    add_event(two, title: title, date: weekday(6 + (index * 7)), students: aldermans, notes: note)
  end
  add_event(two, title: 'Term planning, no lessons', date: weekday(17), notes: 'Next term mapped out.')

  # Ten students across a dozen subjects, including the specialist ones a
  # bigger family splits out.
  two_subjects =
    ['Math', 'Language Arts', 'Science', 'History', 'Geography', 'Latin', 'Logic',
     'Art', 'Music Theory', 'Physical Education', 'Typing', 'Home Economics']
    .each_with_index.map { |name, index| add_subject(two, name, index) }

  # A mark book at the scale that makes the filters earn their place: eighteen
  # pieces across a dozen subjects, most of the roster on each. The marking
  # runs from fully done on the oldest work to untouched on the newest, which
  # is what a term looks like part way through.
  # Marcus runs a classical school room, where the long written piece at the
  # end of a unit is the thing that counts.
  two_paper = add_assignment_type(two, name: 'Term Paper', weight: 3)

  18.times do |index|
    subject = two_subjects[index % two_subjects.length]
    holders = aldermans.rotate(index).first(3 + (index % 4))
    possible = [10, 20, 25, 50, 100][index % 5]

    # Older work is marked, the middle is part marked, the newest is not
    # touched yet. Every fourth student in a part marked batch is left unmarked
    # rather than the same one each time.
    scores = holders.each_with_index.to_h do |student, slot|
      earned =
        if index < 7 then possible - ((index + slot) % 5)
        elsif index < 13 then (slot % 4 == 3 ? nil : possible - ((index + slot) % 7))
        end

      [student, earned]
    end

    add_assignment(
      two, subject: subject, title: "#{subject.name}: unit #{(index / 3) + 1} work",
      due: weekday(index), points: possible,
      weight: [1, 1, 2, 0.5, 3, 1][index % 6], scores: scores
    )
  end

  # One zero weight piece and one nobody has been given yet, so the states the
  # smaller families show are reachable on the busy account too.
  add_assignment(two, subject: two_subjects[7], title: 'Sketchbook practice pages',
                      due: weekday(5), points: 10, weight: 0,
                      scores: aldermans.first(4).to_h { |student| [student, 9] })
  add_assignment(two, subject: two_subjects[6], title: 'Logic: term paper', due: weekday(20),
                      type: two_paper,
                      points: 100, weight: 3)

  # Marked by letter rather than by percentage, on a recitation where a number
  # out of ten was never the point. Every letter on the scale appears, so the
  # key on the scoring panel has something to stand next to.
  add_assignment(
    two, subject: two_subjects[8], title: 'Recitation: autumn poem', due: weekday(8),
    points: 20, type: built_in_type(two, 'Quiz'),
    scores: aldermans.first(5).each_with_index.to_h { |student, index| [student, %w[A B C D F][index]] }
  )

  # An explicit zero next to real marks: work that was set, not done, and
  # counts as nothing earned rather than being left unmarked.
  add_assignment(
    two, subject: two_subjects[0], title: 'Math: end of unit test', due: weekday(11),
    points: 50, type: built_in_type(two, 'Test'),
    scores: { aldermans[0] => 47, aldermans[1] => 0, aldermans[2] => 39, aldermans[3] => nil }
  )

  # No due date, so it belongs to no report period and shows on the list and in
  # no figure: the ongoing portfolio a classical school room keeps all year.
  add_assignment(
    two, subject: two_subjects[3], title: 'Commonplace book, ongoing', points: 25,
    notes: 'Added to through the year rather than handed in.',
    scores: aldermans.first(3).to_h { |student| [student, 22] }
  )

  # A long list, so the dashboard panel has more open work than it shows and
  # the See More link has somewhere to go.
  [
    ['Order ten sets of lab goggles', -9], ['Chase the missing algebra workbook', -4],
    ['File the annual assessment paperwork', -1], ['Pay the co-op dues', 0],
    ['Book the debate tournament hotel', 1], ['Restock the art cupboard', 3],
    ['Plan the October field trip', 5], ['Renew the maths software licence', 8],
    ['Email the piano teacher about recital slots', 12]
  ].each { |title, offset| add_task(two, title: title, due: Date.current + offset) }

  add_task(two, title: 'Sort out the shed storage')

  # A weekly series on a busy account, with two weeks already ticked.
  registers = repeat(
    add_task(two, title: 'Mark the weekly registers', due: last_weekday(1)),
    frequency: 'weekly', weekdays: [1]
  )
  tick_occurrence(registers, last_weekday(1), done_days_ago: 0)
  tick_occurrence(registers, last_weekday(1) - 7, done_days_ago: 7)

  # A daily series with an end, and one occurrence edited out into a task of
  # its own: the same shapes the small account has, at ten children's scale.
  lunches = repeat(
    add_task(two, title: 'Pack lunches for the morning', due: Date.current,
                  students: aldermans.first(4), owned_by: 'both'),
    frequency: 'daily', until_date: Date.current + 45
  )
  tick_occurrence(lunches, Date.current - 1, done_days_ago: 1)
  edit_task_occurrence(lunches, Date.current + 2, title: 'Pack lunches, plus the co-op picnic')

  # The same date every month, on the household admin nobody enjoys.
  repeat(
    add_task(two, title: 'Reconcile the curriculum budget', due: Date.new(ANCHOR.year, ANCHOR.month, 28)),
    frequency: 'monthly', monthly_anchor: 'day_of_month'
  )
  add_task(two, title: 'Order the winter term curriculum', due: Date.current - 14, done_days_ago: 6)
  add_task(two, title: 'Send term one progress notes to grandparents', done_days_ago: 2)

  # Ten children means the filter has to narrow to one of them, so each of the
  # older five carries their own work and the younger ones share a chore.
  aldermans.first(5).each_with_index do |student, index|
    add_task(two, title: "#{student.first_name}: finish the term project",
                  due: Date.current + index, students: [student], owned_by: 'student')
  end
  add_task(two, title: 'Clear the lunch table between lessons', due: Date.current + 2,
                students: aldermans.last(4), owned_by: 'student')
  add_task(two, title: 'Practise reading aloud together', due: Date.current + 5,
                students: aldermans.first(2), owned_by: 'both')
  add_task(two, title: 'Chase the missing algebra workbook for Josiah', due: Date.current - 4,
                students: [aldermans[0]])

  # Ten children means report cards in bulk: four issued for the term that
  # finished, and two drafts for the one running.
  aldermans.first(4).each_with_index do |student, index|
    add_report_card(
      two, student: student, title: 'Michaelmas term', from: ANCHOR - 60, to: ANCHOR - 1,
      comments: 'Issued at the end of Michaelmas.', issued: true,
      # One of the four carries an override, on the subject where a written
      # piece showed more than the marks did.
      overrides: index.zero? ? { two_subjects[6] => ['A', 'The term paper was the best work he has done'] } : {},
      subject_comments: index.zero? ? { two_subjects[0] => 'Algebra is clicking.' } : {}
    )
  end

  aldermans[4..5].each do |student|
    add_report_card(
      two, student: student, title: 'Hilary term so far', from: ANCHOR, to: Date.current
    )
  end

  # 3: brand new. No students, no events, no subjects: every empty state at once.
  demo_teacher(email: 'teacher3@test.com', first_name: 'Priya', last_name: 'Raghavan')

  # 4: a teacher outside America/New_York, with evenings that land on the next
  # UTC day. 6pm through 9pm Pacific is 1am through 4am UTC, so these only sit on
  # the right day if the range and grouping honour her zone.
  four = demo_teacher(email: 'teacher4@test.com', first_name: 'Dana', last_name: 'Okafor',
                      time_zone: 'America/Los_Angeles')
  okafors = [
    add_student(four, 'Zuri', 'Okafor', 6, 2),
    add_student(four, 'Amara', 'Okafor', 4, 5),
    add_student(four, 'Kene', 'Okafor', 2, 8)
  ]

  12.times do |index|
    add_event(
      four,
      title: ['Evening read aloud', 'Astronomy: backyard session', 'Family Bible study',
              'Violin practice', 'Chess club (online)', 'Science documentary'][index % 6],
      date: weekday(index), hour: [[18, 0], [19, 30], [20, 30]][index % 3], minutes: 75,
      students: okafors.sample(1 + (index % 2)),
      location: index.even? ? 'Living room' : 'Back porch'
    )
  end

  6.times do |index|
    add_event(four, title: SUBJECTS[(index + 4) % SUBJECTS.length], date: weekday(index * 2),
                    hour: [10, 0], minutes: 50, students: [okafors[index % okafors.length]],
                    location: 'Kitchen table')
  end

  # Pacific, and repeating every week with no end: the series runs straight
  # through the November change, so its occurrences read 7pm on both sides of
  # it while sitting at two different UTC instants. This is the one to look at
  # when checking that expansion happens in the teacher's zone.
  repeat(
    add_event(four, title: 'Evening sky watch', date: ANCHOR, hour: [19, 0], minutes: 60,
                    students: okafors, location: 'Back porch'),
    frequency: 'weekly', weekdays: [5]
  )

  four_astronomy = add_subject(four, 'Astronomy', 4, 'Backyard observation and the night sky')
  four_biology = add_subject(four, 'Biology', 2)
  four_literature = add_subject(four, 'Literature', 5, 'Read alouds and the evening chapter book')
  add_subject(four, 'Violin', 6)

  # An evening school's mark book: small, mostly marked, one piece still open.
  zuri, amara, kene = okafors

  # Amara's house is a science house: the write up after the practical is its
  # own kind of work, and it counts double.
  four_lab = add_assignment_type(four, name: 'Lab Report', weight: 2)

  add_assignment(four, subject: four_astronomy, title: 'Moon phase observation log',
                       type: four_lab,
                       due: weekday(3), points: 20, weight: 2,
                       notes: 'One sketch a night for two weeks.',
                       scores: { zuri => 19, amara => 17, kene => 12 })
  add_assignment(four, subject: four_astronomy, title: 'Constellation quiz', due: weekday(9),
                       type: built_in_type(four, 'Quiz'),
                       points: 15, weight: 1, scores: { zuri => 14, amara => nil })
  add_assignment(four, subject: four_biology, title: 'Cell diagram labelling', due: weekday(6),
                       points: 25, weight: 1, scores: { zuri => 22, amara => 25, kene => 0 })
  add_assignment(four, subject: four_literature, title: 'Chapter book response',
                       due: weekday(12), points: 10, weight: 0.5,
                       scores: { zuri => nil, amara => nil, kene => nil })

  add_task(four, title: 'Swap the telescope filters before Thursday', due: Date.current + 3)
  add_task(four, title: 'Renew the observatory membership', due: Date.current - 3)
  add_task(four, title: 'Label the rock samples', students: [zuri, amara], owned_by: 'student')
  add_task(four, title: 'Order the violin sheet music', done_days_ago: 4, students: [kene])
  add_task(four, title: 'Keep the observation log up to date', due: Date.current + 1,
                 students: [zuri], owned_by: 'both')

  # 5: one student, the simplest real case.
  five = demo_teacher(email: 'teacher5@test.com', first_name: 'Grace', last_name: 'Bellweather')
  wren = add_student(five, 'Wren', 'Bellweather', 3, 12)
  10.times do |index|
    add_event(five, title: SUBJECTS[index % SUBJECTS.length], date: weekday(index),
                    hour: [9, 30], minutes: 45, students: [wren], location: 'Kitchen table',
                    notes: NOTES[index % NOTES.length])
  end

  five_phonics = add_subject(five, 'Phonics', 0)
  five_math = add_subject(five, 'Math', 4)
  five_nature = add_subject(five, 'Nature Study', 2, 'Weekly walk and a notebook page')

  # One student, everything marked: the report that is simply complete, and the
  # one to read a hand calculation against.
  add_assignment(five, subject: five_phonics, title: 'Short vowel sounds', due: weekday(2),
                       points: 10, weight: 1, scores: { wren => 9 })
  add_assignment(five, subject: five_phonics, title: 'Blending practice', due: weekday(7),
                       points: 10, weight: 1, scores: { wren => 8 })
  add_assignment(five, subject: five_math, title: 'Counting to one hundred', due: weekday(4),
                       points: 20, weight: 2, scores: { wren => 18 })
  add_assignment(five, subject: five_nature, title: 'Autumn leaf notebook page',
                       due: weekday(10), points: 5, weight: 1, scores: { wren => 5 })

  add_task(five, title: 'Buy a new reading journal', due: Date.current + 4, students: [wren])
  add_task(five, title: 'Ask the library about the phonics programme')
  add_task(five, title: 'Read the first reader to me', due: Date.current + 2,
                 students: [wren], owned_by: 'student')

  # 6: everything in the past, nothing upcoming.
  six = demo_teacher(email: 'teacher6@test.com', first_name: 'Owen', last_name: 'Castellano')
  castellanos = [
    add_student(six, 'Marco', 'Castellano', 7, 1),
    add_student(six, 'Lucia', 'Castellano', 5, 10)
  ]
  14.times do |index|
    add_event(six, title: SUBJECTS[index % SUBJECTS.length], date: (ANCHOR - 2.months) + (index * 3).days,
                   hour: [10, 0], minutes: 60, students: castellanos.sample(1),
                   location: 'Home classroom')
  end

  six_math = add_subject(six, 'Math', 0)
  six_reading = add_subject(six, 'Reading', 4)

  # Finished work, two months back with the rest of his year. A progress report
  # opened on its default period finds nothing, which is the honest answer for
  # an account whose work all predates it: widening the From date brings it back.
  add_assignment(six, subject: six_math, title: 'End of term arithmetic test',
                      due: (ANCHOR - 2.months) + 4.days, points: 50, weight: 3,
                      scores: { castellanos[0] => 41, castellanos[1] => 46 })
  add_assignment(six, subject: six_reading, title: 'Summer reading list narration',
                      due: (ANCHOR - 2.months) + 11.days, points: 20, weight: 1,
                      scores: { castellanos[0] => 17, castellanos[1] => 20 })

  # Nothing outstanding: the list exists but every item is ticked, which is a
  # different empty panel from having no tasks at all.
  add_task(six, title: 'File the attendance record for last term', due: Date.current - 30, done_days_ago: 25)
  add_task(six, title: 'Return the borrowed microscope', due: Date.current - 20, done_days_ago: 18)
  add_task(six, title: 'Archive the summer photographs', done_days_ago: 12)
  add_task(six, title: 'Hand in the summer reading sheet', due: Date.current - 26,
                done_days_ago: 24, students: castellanos, owned_by: 'student')

  # 7: everything ahead, nothing has happened yet.
  seven = demo_teacher(email: 'teacher7@test.com', first_name: 'Beatrice', last_name: 'Nakamura')
  nakamuras = [
    add_student(seven, 'Kai', 'Nakamura', 4, 3),
    add_student(seven, 'Yuki', 'Nakamura', 2, 7)
  ]
  14.times do |index|
    title, location = ACTIVITIES[index % ACTIVITIES.length]
    add_event(seven, title: title, date: (ANCHOR + 1.month) + (index * 2).days,
                     hour: [13, 0], minutes: 60, students: nakamuras.sample(1), location: location)
  end

  seven_math = add_subject(seven, 'Math', 0)
  seven_science = add_subject(seven, 'Science', 2)
  seven_japanese = add_subject(seven, 'Japanese', 5, 'Hiragana first, then basic conversation')

  # Set for next month and not marked, because none of it has happened yet.
  # Every row on her list reads "0 of 2 marked", which is the state the
  # Needs marking filter exists for.
  [[seven_math, 'Place value worksheet', 20, 1], [seven_science, 'Weather chart', 15, 2],
   [seven_japanese, 'Hiragana set one', 25, 1], [seven_japanese, 'Greetings dialogue', 10, 0.5]]
    .each_with_index do |(subject, title, points, weight), index|
      add_assignment(seven, subject: subject, title: title,
                            due: (ANCHOR + 1.month) + (index * 3).days,
                            points: points, weight: weight,
                            scores: nakamuras.to_h { |student| [student, nil] })
    end

  add_task(seven, title: 'Confirm the co-op registration', due: Date.current + 10)
  add_task(seven, title: 'Order the spring term books', due: Date.current + 21)
  add_task(seven, title: 'Choose a Japanese name chart', due: Date.current + 14,
                  students: nakamuras, owned_by: 'student')

  # 8: students on the roster, nothing on the calendar, and neither tasks nor
  # subjects: the other teacher whose empty states are worth looking at.
  eight = demo_teacher(email: 'teacher8@test.com', first_name: 'Ruth', last_name: 'Adeyemi')
  add_student(eight, 'Folake', 'Adeyemi', 6, 4)
  add_student(eight, 'Tunde', 'Adeyemi', 3, 8)
  add_student(eight, 'Simi', 'Adeyemi', 1, 11)

  # 9: long names and long titles, for the truncation in roster cards, month
  # pills and week columns.
  nine = demo_teacher(email: 'teacher9@test.com', first_name: 'Anastasia', last_name: 'Vandersteen')
  vandersteens = [
    add_student(nine, 'Bartholomew', 'Vandersteen-Kowalczyk', 8, 5, middle_name: 'Fitzgerald'),
    add_student(nine, 'Wilhelmina', 'Vandersteen-Kowalczyk', 6, 2, middle_name: 'Josephine'),
    add_student(nine, 'Xu', 'Vandersteen-Kowalczyk', 2, 9)
  ]
  [
    'Advanced Placement European History seminar and discussion group',
    'Intermediate conversational Spanish with the co-op tutoring circle',
    'Quarterly standardized assessment preparation and review session',
    'Marine biology field study at the coastal research station',
    'Orchestra sectional rehearsal for the winter concert program'
  ].each_with_index do |title, index|
    add_event(nine, title: title, date: weekday(index * 3),
                    hour: [[9, 0], [11, 0], [14, 0]][index % 3], minutes: 90,
                    students: vandersteens.sample(1 + (index % 3)),
                    location: 'Pemberton Community Education Center, east wing')
  end

  nine_history = add_subject(nine, 'Advanced Placement European History', 9,
                             'Seminar format, with the co-op discussion group on alternate weeks')
  nine_spanish = add_subject(nine, 'Intermediate Conversational Spanish', 2)

  # Long titles against long student names, for the wrapping on the row and in
  # the score panel.
  add_assignment(nine, subject: nine_history,
                       title: 'Comparative analysis of the Congress of Vienna and the ' \
                              'settlement at Westphalia',
                       due: weekday(4), points: 100, weight: 3,
                       notes: 'Twelve hundred words, with the seminar reading list cited in ' \
                              'full at the end.',
                       scores: { vandersteens[0] => 88, vandersteens[1] => 91,
                                 vandersteens[2] => nil })
  add_assignment(nine, subject: nine_spanish,
                       title: 'Sustained conversational assessment with the co-op tutoring ' \
                              'circle',
                       due: weekday(11), points: 40, weight: 2,
                       scores: { vandersteens[1] => 34, vandersteens[2] => 0 })

  add_task(nine, title: 'Coordinate the interdisciplinary humanities portfolio review with the ' \
                        'co-op assessment panel before the end of the term',
                 due: Date.current + 7,
                 notes: 'The panel wants the reading lists, the essay drafts and the marking ' \
                        'rubric in one folder rather than three.')
  add_task(nine, title: 'Reconcile the Pemberton Community Education Centre invoices against ' \
                        'the quarterly enrichment budget')
  add_task(nine, title: 'Complete the independent research proposal for the marine biology ' \
                        'field study before the coastal station deadline',
                 due: Date.current + 5, students: vandersteens.first(2), owned_by: 'student')

  # 10: nearly empty. One student, one event, one task.
  ten = demo_teacher(email: 'teacher10@test.com', first_name: 'Miriam', last_name: 'Holt')
  holt = add_student(ten, 'June', 'Holt', 0, 6)
  add_event(ten, title: 'First day of school', date: weekday(1), hour: [9, 0], minutes: 60,
                 students: [holt], location: 'Kitchen table',
                 notes: 'Take the front porch photo before we start.')
  ten_readiness = add_subject(ten, 'Kindergarten Readiness', 6,
                              'Letters, numbers and lots of reading')

  # One piece of work, not yet marked: the smallest mark book there is.
  add_assignment(ten, subject: ten_readiness, title: 'Name writing practice', due: weekday(2),
                      points: 5, weight: 1, scores: { holt => nil })

  add_task(ten, title: 'Take the first day photo', due: Date.current + 1, students: [holt])
end

puts "Seeded demo teachers, anchored on #{ANCHOR}. Password for all: #{PASSWORD}"
Teacher.where(email: SEED_EMAILS).sort_by { |t| t.email.delete('^0-9').to_i }.each do |teacher|
  puts format(
    '  %-20s %-24s students: %2d (+%d removed)  events: %4d (%d series)  tasks: %2d (%d open, %d theirs, %d repeating)  ' \
    'subjects: %2d  types: %d (%d custom)  assignments: %2d (%d weighted by hand)  ' \
    'grades: %3d (%d marked, %d by letter)  cards: %d (%d issued, %d versions)  %s',
    teacher.email, teacher.full_name,
    teacher.students.active.count, teacher.students.where(is_active: false).count,
    teacher.calendar_events.count,
    Recurrence.where(recurrable_type: 'CalendarEvent',
                     recurrable_id: teacher.calendar_events.select(:id)).count,
    teacher.tasks.count, teacher.tasks.where(completed_at: nil).count,
    teacher.tasks.where.not(owned_by: 'teacher').count, teacher.tasks.series.count,
    teacher.subjects.active.count,
    teacher.assignment_types.active.count, teacher.assignment_types.active.custom.count,
    teacher.assignments.count, teacher.assignments.where(weight_overridden: true).count,
    AssignmentGrade.joins(:assignment).where(assignments: { teacher_id: teacher.id }).count,
    AssignmentGrade.joins(:assignment)
                   .where(assignments: { teacher_id: teacher.id })
                   .where.not(points_earned: nil).count,
    AssignmentGrade.joins(:assignment)
                   .where(assignments: { teacher_id: teacher.id })
                   .where.not(entered_letter: nil).count,
    teacher.report_cards.select(:group_id).distinct.count,
    teacher.report_cards.issued.count, teacher.report_cards.count,
    teacher.effective_time_zone
  )
end
