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
  teacher.students.destroy_all
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

  # 3: brand new. No students, no events: every empty state at once.
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

  # 5: one student, the simplest real case.
  five = demo_teacher(email: 'teacher5@test.com', first_name: 'Grace', last_name: 'Bellweather')
  wren = add_student(five, 'Wren', 'Bellweather', 3, 12)
  10.times do |index|
    add_event(five, title: SUBJECTS[index % SUBJECTS.length], date: weekday(index),
                    hour: [9, 30], minutes: 45, students: [wren], location: 'Kitchen table',
                    notes: NOTES[index % NOTES.length])
  end

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

  # 8: students on the roster, nothing on the calendar.
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

  # 10: nearly empty. One student, one event.
  ten = demo_teacher(email: 'teacher10@test.com', first_name: 'Miriam', last_name: 'Holt')
  holt = add_student(ten, 'June', 'Holt', 0, 6)
  add_event(ten, title: 'First day of school', date: weekday(1), hour: [9, 0], minutes: 60,
                 students: [holt], location: 'Kitchen table',
                 notes: 'Take the front porch photo before we start.')
end

puts "Seeded demo teachers, anchored on #{ANCHOR}. Password for all: #{PASSWORD}"
Teacher.where(email: SEED_EMAILS).sort_by { |t| t.email.delete('^0-9').to_i }.each do |teacher|
  puts format(
    '  %-20s %-24s students: %2d (+%d removed)  events: %4d  %s',
    teacher.email, teacher.full_name,
    teacher.students.active.count, teacher.students.where(is_active: false).count,
    teacher.calendar_events.count, teacher.effective_time_zone
  )
end
