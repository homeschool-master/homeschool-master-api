# Homeschool Management App - Database Architecture Document

**Version:** 1.0  
**Date:** November 14, 2025  
**Status:** Initial Design

---

## Table of Contents
1. [Overview](#overview)
2. [Database Schema](#database-schema)
3. [Entity Relationship Diagram](#entity-relationship-diagram)
4. [Detailed Entity Definitions](#detailed-entity-definitions)
5. [Relationships & Constraints](#relationships--constraints)
6. [Indexing Strategy](#indexing-strategy)
7. [Data Access Patterns](#data-access-patterns)
8. [Future Considerations](#future-considerations)

---

## Overview

### Purpose
This document defines the database architecture for a homeschool management mobile application designed to help teachers (homeschool parents) manage their students' education, including calendaring, assignments, grading, task management, and expense tracking.

### Scope
- **Phase:** MVP (Minimum Viable Product)
- **Users:** Individual teachers managing their own students
- **Key Features:** Profile management, calendar, task lists, assignments, report cards, expense tracking, and lesson plan sharing

### Technology Assumptions
- Relational database structure (compatible with PostgreSQL, MySQL, or SQLite)
- Mobile-first design with offline capability considerations
- Support for future multi-tenant architecture

---

## Database Schema

### Core Entities

```
1. Teachers
2. Students
3. Calendar_Events
4. Event_Types
5. Assignments
6. Tasks
7. Report_Cards
8. Report_Card_Entries
9. Expenses
10. Expense_Categories
11. Subjects
12. Lesson_Plans
13. Teacher_Connections
14. Event_Attendees
15. Shared_Lesson_Plans
```

---

## Entity Relationship Diagram

```
┌─────────────┐         ┌─────────────┐
│  Teachers   │1──────*│  Students   │
└─────────────┘         └─────────────┘
       │1                      │1
       │                       │
       │*                      │*
┌─────────────────┐    ┌──────────────┐
│ Calendar_Events │    │ Assignments  │
└─────────────────┘    └──────────────┘
       │*                      │*
       │                       │
       │1                      │1
┌─────────────┐         ┌─────────────┐
│ Event_Types │         │  Subjects   │
└─────────────┘         └─────────────┘

┌─────────────┐         ┌──────────────┐
│   Tasks     │*──────1│  Students    │
└─────────────┘         └──────────────┘
       │*
       │
       │1
┌─────────────┐
│  Teachers   │
└─────────────┘

┌──────────────┐        ┌─────────────────────┐
│ Report_Cards │1─────*│ Report_Card_Entries │
└──────────────┘        └─────────────────────┘
       │*
       │
       │1
┌─────────────┐
│  Students   │
└─────────────┘

┌─────────────┐         ┌────────────────────┐
│  Expenses   │*──────1│ Expense_Categories │
└─────────────┘         └────────────────────┘
       │*
       │
       │1 (optional)
┌─────────────┐
│  Students   │
└─────────────┘

┌──────────────┐        ┌──────────────────────┐
│ Lesson_Plans │1─────*│ Shared_Lesson_Plans  │
└──────────────┘        └──────────────────────┘
       │1
       │
       │*
┌─────────────┐
│  Teachers   │
└─────────────┘
```

---

## Detailed Entity Definitions

### 1. Teachers

**Purpose:** Store teacher/parent information

| Column Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| id | UUID/INT | PRIMARY KEY | Unique identifier |
| first_name | VARCHAR(100) | NOT NULL | Teacher's first name |
| last_name | VARCHAR(100) | NOT NULL | Teacher's last name |
| nickname | VARCHAR(100) | NULL | Optional preferred name |
| email | VARCHAR(255) | NOT NULL, UNIQUE | Email address for login |
| phone | VARCHAR(20) | NULL | Contact phone number |
| newsletter_subscribed | BOOLEAN | DEFAULT FALSE | Newsletter opt-in status |
| password_hash | VARCHAR(255) | NOT NULL | Encrypted password |
| profile_image_url | VARCHAR(500) | NULL | Profile picture URL |
| created_at | TIMESTAMP | DEFAULT NOW() | Account creation date |
| updated_at | TIMESTAMP | DEFAULT NOW() | Last update timestamp |
| is_active | BOOLEAN | DEFAULT TRUE | Account status |

**Indexes:**
- PRIMARY KEY on `id`
- UNIQUE INDEX on `email`
- INDEX on `is_active`

---

### 2. Students

**Purpose:** Store student information

| Column Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| id | UUID/INT | PRIMARY KEY | Unique identifier |
| teacher_id | UUID/INT | FOREIGN KEY, NOT NULL | Reference to Teachers table |
| first_name | VARCHAR(100) | NOT NULL | Student's first name |
| last_name | VARCHAR(100) | NOT NULL | Student's last name |
| nickname | VARCHAR(100) | NULL | Optional preferred name |
| date_of_birth | DATE | NULL | Student's birthdate |
| grade_level | VARCHAR(20) | NULL | Current grade (e.g., "5th Grade", "Kindergarten") |
| profile_image_url | VARCHAR(500) | NULL | Profile picture URL |
| notes | TEXT | NULL | Additional notes about student |
| created_at | TIMESTAMP | DEFAULT NOW() | Record creation date |
| updated_at | TIMESTAMP | DEFAULT NOW() | Last update timestamp |
| is_active | BOOLEAN | DEFAULT TRUE | Active status |

**Indexes:**
- PRIMARY KEY on `id`
- FOREIGN KEY on `teacher_id` REFERENCES Teachers(id) ON DELETE CASCADE
- INDEX on `teacher_id`
- INDEX on `is_active`

---

### 3. Event_Types

**Purpose:** Categorize calendar events

| Column Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| id | UUID/INT | PRIMARY KEY | Unique identifier |
| name | VARCHAR(100) | NOT NULL | Event type name |
| color_code | VARCHAR(7) | NULL | Hex color for UI display |
| icon | VARCHAR(50) | NULL | Icon identifier |
| description | TEXT | NULL | Event type description |
| is_system_default | BOOLEAN | DEFAULT FALSE | System-defined or user-created |

**Examples:** "Lesson", "Field Trip", "Co-op Meeting", "Appointment", "Test", "Project Due", "Break/Vacation"

**Indexes:**
- PRIMARY KEY on `id`

---

### 4. Calendar_Events

**Purpose:** Store calendar events for teachers and students

| Column Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| id | UUID/INT | PRIMARY KEY | Unique identifier |
| teacher_id | UUID/INT | FOREIGN KEY, NOT NULL | Event creator |
| event_type_id | UUID/INT | FOREIGN KEY, NULL | Reference to Event_Types |
| title | VARCHAR(255) | NOT NULL | Event title |
| description | TEXT | NULL | Event details |
| location | VARCHAR(255) | NULL | Physical or virtual location |
| start_time | TIMESTAMP | NOT NULL | Event start date/time |
| end_time | TIMESTAMP | NULL | Event end date/time |
| all_day | BOOLEAN | DEFAULT FALSE | All-day event flag |
| recurrence_rule | TEXT | NULL | RRULE format for recurring events |
| recurrence_end_date | DATE | NULL | When recurring event ends |
| is_recurring | BOOLEAN | DEFAULT FALSE | Recurring event flag |
| parent_event_id | UUID/INT | FOREIGN KEY, NULL | Reference for recurring event instances |
| color_code | VARCHAR(7) | NULL | Custom color override |
| reminder_minutes | INT | NULL | Minutes before event to remind |
| created_at | TIMESTAMP | DEFAULT NOW() | Record creation date |
| updated_at | TIMESTAMP | DEFAULT NOW() | Last update timestamp |

**Notes on Recurrence:**
- `recurrence_rule` follows iCalendar RRULE format (e.g., "FREQ=WEEKLY;BYDAY=MO,WE,FR")
- `parent_event_id` links instances to the original recurring event

**Indexes:**
- PRIMARY KEY on `id`
- FOREIGN KEY on `teacher_id` REFERENCES Teachers(id) ON DELETE CASCADE
- FOREIGN KEY on `event_type_id` REFERENCES Event_Types(id) ON DELETE SET NULL
- FOREIGN KEY on `parent_event_id` REFERENCES Calendar_Events(id) ON DELETE CASCADE
- INDEX on `teacher_id`
- INDEX on `start_time`
- INDEX on `is_recurring`

---

### 5. Event_Attendees

**Purpose:** Link students to calendar events (many-to-many relationship)

| Column Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| id | UUID/INT | PRIMARY KEY | Unique identifier |
| event_id | UUID/INT | FOREIGN KEY, NOT NULL | Reference to Calendar_Events |
| student_id | UUID/INT | FOREIGN KEY, NOT NULL | Reference to Students |
| attendance_status | ENUM | NULL | 'pending', 'attended', 'absent', 'excused' |
| created_at | TIMESTAMP | DEFAULT NOW() | Record creation date |

**Indexes:**
- PRIMARY KEY on `id`
- FOREIGN KEY on `event_id` REFERENCES Calendar_Events(id) ON DELETE CASCADE
- FOREIGN KEY on `student_id` REFERENCES Students(id) ON DELETE CASCADE
- UNIQUE INDEX on (`event_id`, `student_id`)
- INDEX on `student_id`

---

### 6. Subjects

**Purpose:** Define academic subjects

| Column Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| id | UUID/INT | PRIMARY KEY | Unique identifier |
| teacher_id | UUID/INT | FOREIGN KEY, NOT NULL | Reference to Teachers |
| name | VARCHAR(100) | NOT NULL | Subject name |
| description | TEXT | NULL | Subject description |
| color_code | VARCHAR(7) | NULL | Hex color for UI display |
| icon | VARCHAR(50) | NULL | Icon identifier |
| created_at | TIMESTAMP | DEFAULT NOW() | Record creation date |
| updated_at | TIMESTAMP | DEFAULT NOW() | Last update timestamp |

**Examples:** "Mathematics", "Language Arts", "Science", "History", "Art", "Physical Education"

**Indexes:**
- PRIMARY KEY on `id`
- FOREIGN KEY on `teacher_id` REFERENCES Teachers(id) ON DELETE CASCADE
- INDEX on `teacher_id`

---

### 7. Assignments

**Purpose:** Track student assignments and homework

| Column Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| id | UUID/INT | PRIMARY KEY | Unique identifier |
| student_id | UUID/INT | FOREIGN KEY, NOT NULL | Reference to Students |
| teacher_id | UUID/INT | FOREIGN KEY, NOT NULL | Reference to Teachers |
| subject_id | UUID/INT | FOREIGN KEY, NULL | Reference to Subjects |
| calendar_event_id | UUID/INT | FOREIGN KEY, NULL | Optional link to calendar event |
| title | VARCHAR(255) | NOT NULL | Assignment title |
| description | TEXT | NULL | Assignment details/instructions |
| due_date | TIMESTAMP | NULL | Optional due date |
| assigned_date | DATE | NOT NULL | Date assignment was given |
| completion_status | ENUM | DEFAULT 'not_started' | 'not_started', 'in_progress', 'completed', 'overdue' |
| completed_date | TIMESTAMP | NULL | When student completed it |
| grade | VARCHAR(10) | NULL | Grade received (flexible format) |
| points_earned | DECIMAL(10,2) | NULL | Points received |
| points_possible | DECIMAL(10,2) | NULL | Total points possible |
| notes | TEXT | NULL | Teacher notes |
| attachments | JSON | NULL | Array of attachment URLs/references |
| created_at | TIMESTAMP | DEFAULT NOW() | Record creation date |
| updated_at | TIMESTAMP | DEFAULT NOW() | Last update timestamp |

**Indexes:**
- PRIMARY KEY on `id`
- FOREIGN KEY on `student_id` REFERENCES Students(id) ON DELETE CASCADE
- FOREIGN KEY on `teacher_id` REFERENCES Teachers(id) ON DELETE CASCADE
- FOREIGN KEY on `subject_id` REFERENCES Subjects(id) ON DELETE SET NULL
- FOREIGN KEY on `calendar_event_id` REFERENCES Calendar_Events(id) ON DELETE SET NULL
- INDEX on `student_id`
- INDEX on `due_date`
- INDEX on `completion_status`

---

### 8. Tasks

**Purpose:** Track to-dos for teachers and students (separate from assignments)

| Column Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| id | UUID/INT | PRIMARY KEY | Unique identifier |
| teacher_id | UUID/INT | FOREIGN KEY, NOT NULL | Reference to Teachers |
| student_id | UUID/INT | FOREIGN KEY, NULL | Optional student assignment |
| title | VARCHAR(255) | NOT NULL | Task title |
| description | TEXT | NULL | Task details |
| due_date | TIMESTAMP | NULL | Optional due date |
| priority | ENUM | DEFAULT 'medium' | 'low', 'medium', 'high' |
| status | ENUM | DEFAULT 'pending' | 'pending', 'in_progress', 'completed', 'cancelled' |
| completed_date | TIMESTAMP | NULL | When task was completed |
| category | VARCHAR(100) | NULL | Task category (e.g., "Planning", "Admin", "Shopping") |
| created_at | TIMESTAMP | DEFAULT NOW() | Record creation date |
| updated_at | TIMESTAMP | DEFAULT NOW() | Last update timestamp |

**Notes:**
- If `student_id` is NULL, task belongs to teacher only
- If `student_id` is set, task is student-specific

**Indexes:**
- PRIMARY KEY on `id`
- FOREIGN KEY on `teacher_id` REFERENCES Teachers(id) ON DELETE CASCADE
- FOREIGN KEY on `student_id` REFERENCES Students(id) ON DELETE CASCADE
- INDEX on `teacher_id`
- INDEX on `student_id`
- INDEX on `status`
- INDEX on `due_date`

---

### 9. Report_Cards

**Purpose:** Store report card periods and configurations

| Column Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| id | UUID/INT | PRIMARY KEY | Unique identifier |
| student_id | UUID/INT | FOREIGN KEY, NOT NULL | Reference to Students |
| teacher_id | UUID/INT | FOREIGN KEY, NOT NULL | Reference to Teachers |
| title | VARCHAR(255) | NOT NULL | Report card title |
| period_type | VARCHAR(50) | NOT NULL | 'weekly', 'monthly', 'quarterly', 'semester', 'annual', 'custom' |
| start_date | DATE | NOT NULL | Period start date |
| end_date | DATE | NOT NULL | Period end date |
| grading_system | ENUM | NOT NULL | 'letter', 'percentage', 'standards' |
| status | ENUM | DEFAULT 'draft' | 'draft', 'finalized', 'published' |
| overall_comments | TEXT | NULL | General comments |
| created_at | TIMESTAMP | DEFAULT NOW() | Record creation date |
| updated_at | TIMESTAMP | DEFAULT NOW() | Last update timestamp |
| published_at | TIMESTAMP | NULL | When report card was finalized |

**Indexes:**
- PRIMARY KEY on `id`
- FOREIGN KEY on `student_id` REFERENCES Students(id) ON DELETE CASCADE
- FOREIGN KEY on `teacher_id` REFERENCES Teachers(id) ON DELETE CASCADE
- INDEX on `student_id`
- INDEX on `start_date`, `end_date`

---

### 10. Report_Card_Entries

**Purpose:** Individual subject grades within a report card

| Column Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| id | UUID/INT | PRIMARY KEY | Unique identifier |
| report_card_id | UUID/INT | FOREIGN KEY, NOT NULL | Reference to Report_Cards |
| subject_id | UUID/INT | FOREIGN KEY, NULL | Reference to Subjects |
| subject_name | VARCHAR(100) | NOT NULL | Subject name (denormalized for flexibility) |
| letter_grade | VARCHAR(5) | NULL | Letter grade (A+, B-, etc.) |
| percentage_grade | DECIMAL(5,2) | NULL | Percentage (0-100) |
| standards_rating | VARCHAR(50) | NULL | Standards-based rating |
| comments | TEXT | NULL | Subject-specific comments |
| created_at | TIMESTAMP | DEFAULT NOW() | Record creation date |
| updated_at | TIMESTAMP | DEFAULT NOW() | Last update timestamp |

**Indexes:**
- PRIMARY KEY on `id`
- FOREIGN KEY on `report_card_id` REFERENCES Report_Cards(id) ON DELETE CASCADE
- FOREIGN KEY on `subject_id` REFERENCES Subjects(id) ON DELETE SET NULL
- INDEX on `report_card_id`

---

### 11. Expense_Categories

**Purpose:** Categorize homeschool expenses

| Column Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| id | UUID/INT | PRIMARY KEY | Unique identifier |
| teacher_id | UUID/INT | FOREIGN KEY, NOT NULL | Reference to Teachers |
| name | VARCHAR(100) | NOT NULL | Category name |
| description | TEXT | NULL | Category description |
| color_code | VARCHAR(7) | NULL | Hex color for UI display |
| icon | VARCHAR(50) | NULL | Icon identifier |
| is_system_default | BOOLEAN | DEFAULT FALSE | System-defined or user-created |
| created_at | TIMESTAMP | DEFAULT NOW() | Record creation date |

**Examples:** "Curriculum", "Books", "Supplies", "Field Trips", "Online Subscriptions", "Art Supplies", "Sports Equipment"

**Indexes:**
- PRIMARY KEY on `id`
- FOREIGN KEY on `teacher_id` REFERENCES Teachers(id) ON DELETE CASCADE
- INDEX on `teacher_id`

---

### 12. Expenses

**Purpose:** Track homeschool-related expenses

| Column Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| id | UUID/INT | PRIMARY KEY | Unique identifier |
| teacher_id | UUID/INT | FOREIGN KEY, NOT NULL | Reference to Teachers |
| student_id | UUID/INT | FOREIGN KEY, NULL | Optional student association |
| subject_id | UUID/INT | FOREIGN KEY, NULL | Optional subject association |
| category_id | UUID/INT | FOREIGN KEY, NULL | Reference to Expense_Categories |
| expense_date | DATE | NOT NULL | Date of expense |
| amount | DECIMAL(10,2) | NOT NULL | Expense amount |
| currency | VARCHAR(3) | DEFAULT 'USD' | Currency code |
| vendor | VARCHAR(255) | NULL | Where purchased |
| description | TEXT | NOT NULL | Expense description |
| receipt_url | VARCHAR(500) | NULL | Receipt image/document URL |
| payment_method | VARCHAR(50) | NULL | How it was paid |
| is_tax_deductible | BOOLEAN | DEFAULT TRUE | Tax deduction flag |
| notes | TEXT | NULL | Additional notes |
| tags | JSON | NULL | Array of custom tags for filtering |
| created_at | TIMESTAMP | DEFAULT NOW() | Record creation date |
| updated_at | TIMESTAMP | DEFAULT NOW() | Last update timestamp |

**Notes:**
- If `student_id` is NULL, expense is general/household
- If `student_id` is set, expense is student-specific
- `tags` allows custom categorization (e.g., ["event", "annual", "one-time"])

**Indexes:**
- PRIMARY KEY on `id`
- FOREIGN KEY on `teacher_id` REFERENCES Teachers(id) ON DELETE CASCADE
- FOREIGN KEY on `student_id` REFERENCES Students(id) ON DELETE SET NULL
- FOREIGN KEY on `subject_id` REFERENCES Subjects(id) ON DELETE SET NULL
- FOREIGN KEY on `category_id` REFERENCES Expense_Categories(id) ON DELETE SET NULL
- INDEX on `teacher_id`
- INDEX on `student_id`
- INDEX on `expense_date`
- INDEX on `category_id`

---

### 13. Lesson_Plans

**Purpose:** Store lesson plans created by teachers

| Column Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| id | UUID/INT | PRIMARY KEY | Unique identifier |
| teacher_id | UUID/INT | FOREIGN KEY, NOT NULL | Reference to Teachers |
| subject_id | UUID/INT | FOREIGN KEY, NULL | Reference to Subjects |
| title | VARCHAR(255) | NOT NULL | Lesson plan title |
| description | TEXT | NULL | Lesson overview |
| content | TEXT | NULL | Full lesson plan content |
| grade_level | VARCHAR(50) | NULL | Target grade level |
| duration_minutes | INT | NULL | Estimated lesson duration |
| objectives | TEXT | NULL | Learning objectives |
| materials_needed | TEXT | NULL | Required materials |
| activities | JSON | NULL | Structured activity list |
| assessment_methods | TEXT | NULL | How to assess learning |
| notes | TEXT | NULL | Additional notes |
| attachments | JSON | NULL | Array of attachment URLs |
| is_template | BOOLEAN | DEFAULT FALSE | Reusable template flag |
| visibility | ENUM | DEFAULT 'private' | 'private', 'public' |
| view_count | INT | DEFAULT 0 | Number of views (for public) |
| created_at | TIMESTAMP | DEFAULT NOW() | Record creation date |
| updated_at | TIMESTAMP | DEFAULT NOW() | Last update timestamp |

**Indexes:**
- PRIMARY KEY on `id`
- FOREIGN KEY on `teacher_id` REFERENCES Teachers(id) ON DELETE CASCADE
- FOREIGN KEY on `subject_id` REFERENCES Subjects(id) ON DELETE SET NULL
- INDEX on `teacher_id`
- INDEX on `visibility`
- INDEX on `is_template`

---

### 14. Shared_Lesson_Plans

**Purpose:** Track lesson plan sharing between teachers

| Column Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| id | UUID/INT | PRIMARY KEY | Unique identifier |
| lesson_plan_id | UUID/INT | FOREIGN KEY, NOT NULL | Reference to Lesson_Plans |
| shared_by_teacher_id | UUID/INT | FOREIGN KEY, NOT NULL | Teacher who shared |
| shared_with_teacher_id | UUID/INT | FOREIGN KEY, NULL | Specific teacher recipient (for private shares) |
| share_type | ENUM | NOT NULL | 'private', 'public' |
| can_edit | BOOLEAN | DEFAULT FALSE | Edit permission flag |
| shared_date | TIMESTAMP | DEFAULT NOW() | When it was shared |
| view_count | INT | DEFAULT 0 | Number of times viewed |
| copied_count | INT | DEFAULT 0 | Number of times copied |

**Notes:**
- If `share_type` is 'public', `shared_with_teacher_id` is NULL
- If `share_type` is 'private', `shared_with_teacher_id` identifies recipient

**Indexes:**
- PRIMARY KEY on `id`
- FOREIGN KEY on `lesson_plan_id` REFERENCES Lesson_Plans(id) ON DELETE CASCADE
- FOREIGN KEY on `shared_by_teacher_id` REFERENCES Teachers(id) ON DELETE CASCADE
- FOREIGN KEY on `shared_with_teacher_id` REFERENCES Teachers(id) ON DELETE CASCADE
- INDEX on `lesson_plan_id`
- INDEX on `share_type`
- UNIQUE INDEX on (`lesson_plan_id`, `shared_with_teacher_id`) WHERE share_type = 'private'

---

### 15. Teacher_Connections

**Purpose:** Manage teacher-to-teacher relationships for private sharing (Future: v2.0)

| Column Name | Data Type | Constraints | Description |
|------------|-----------|-------------|-------------|
| id | UUID/INT | PRIMARY KEY | Unique identifier |
| teacher_id | UUID/INT | FOREIGN KEY, NOT NULL | Requesting teacher |
| connected_teacher_id | UUID/INT | FOREIGN KEY, NOT NULL | Connected teacher |
| status | ENUM | DEFAULT 'pending' | 'pending', 'accepted', 'blocked' |
| created_at | TIMESTAMP | DEFAULT NOW() | Connection request date |
| accepted_at | TIMESTAMP | NULL | When connection was accepted |

**Notes:**
- This table supports future social features
- Not required for MVP but included for forward compatibility

**Indexes:**
- PRIMARY KEY on `id`
- FOREIGN KEY on `teacher_id` REFERENCES Teachers(id) ON DELETE CASCADE
- FOREIGN KEY on `connected_teacher_id` REFERENCES Teachers(id) ON DELETE CASCADE
- UNIQUE INDEX on (`teacher_id`, `connected_teacher_id`)
- INDEX on `status`

---

## Relationships & Constraints

### Primary Relationships

1. **Teacher → Students** (One-to-Many)
   - One teacher can have multiple students
   - Each student belongs to one teacher
   - CASCADE DELETE: Deleting teacher removes all associated students

2. **Teacher → Calendar_Events** (One-to-Many)
   - One teacher creates multiple events
   - CASCADE DELETE: Deleting teacher removes all their events

3. **Calendar_Events → Event_Attendees → Students** (Many-to-Many)
   - Events can have multiple student attendees
   - Students can attend multiple events
   - CASCADE DELETE: Deleting event or student removes attendee records

4. **Student → Assignments** (One-to-Many)
   - One student can have multiple assignments
   - CASCADE DELETE: Deleting student removes all their assignments

5. **Assignments → Calendar_Events** (Many-to-One, Optional)
   - Assignments can optionally link to a calendar event
   - SET NULL: Deleting event doesn't delete assignment

6. **Student → Tasks** (One-to-Many, Optional)
   - Tasks can be student-specific or teacher-only
   - CASCADE DELETE: Deleting student removes their tasks

7. **Student → Report_Cards** (One-to-Many)
   - One student can have multiple report cards
   - CASCADE DELETE: Deleting student removes all report cards

8. **Report_Card → Report_Card_Entries** (One-to-Many)
   - One report card has multiple subject entries
   - CASCADE DELETE: Deleting report card removes all entries

9. **Teacher → Expenses** (One-to-Many)
   - Teacher tracks all expenses
   - CASCADE DELETE: Deleting teacher removes expenses

10. **Expenses → Students** (Many-to-One, Optional)
    - Expenses can be general or student-specific
    - SET NULL: Deleting student doesn't delete expense

11. **Teacher → Lesson_Plans** (One-to-Many)
    - Teacher creates multiple lesson plans
    - CASCADE DELETE: Deleting teacher removes their lesson plans

12. **Lesson_Plans → Shared_Lesson_Plans** (One-to-Many)
    - Lesson plans can be shared multiple times
    - CASCADE DELETE: Deleting lesson plan removes share records

### Referential Integrity Rules

- **ON DELETE CASCADE**: Used for core parent-child relationships where child data is meaningless without parent
- **ON DELETE SET NULL**: Used for optional references where data should be preserved
- **ON DELETE RESTRICT**: Not used in MVP; consider for critical data in future versions

---

## Indexing Strategy

### Performance Considerations

**High-Priority Indexes (MVP):**

1. **Teachers Table:**
   - `email` (UNIQUE) - Login lookups
   - `is_active` - Filter active accounts

2. **Students Table:**
   - `teacher_id` - Fetch all students for a teacher
   - `is_active` - Filter active students

3. **Calendar_Events Table:**
   - `teacher_id` - Fetch teacher's events
   - `start_time` - Date range queries
   - Composite: (`teacher_id`, `start_time`) - Common query pattern

4. **Event_Attendees Table:**
   - `event_id` - Get attendees for event
   - `student_id` - Get student's schedule
   - UNIQUE: (`event_id`, `student_id`) - Prevent duplicates

5. **Assignments Table:**
   - `student_id` - Student's assignment list
   - `due_date` - Upcoming assignments
   - `completion_status` - Filter by status
   - Composite: (`student_id`, `due_date`) - Common query

6. **Tasks Table:**
   - `teacher_id` - Teacher's task list
   - `student_id` - Student's tasks
   - `status` - Filter by completion
   - `due_date` - Upcoming tasks

7. **Expenses Table:**
   - `teacher_id` - All teacher expenses
   - `student_id` - Student-specific expenses
   - `expense_date` - Date range queries
   - `category_id` - Category filtering
   - Composite: (`teacher_id`, `expense_date`) - Report generation

8. **Report_Cards Table:**
   - `student_id` - Student's report cards
   - Composite: (`student_id`, `start_date`, `end_date`) - Period lookups

**Future Optimization (Post-MVP):**
- Full-text search indexes on `title`, `description` fields
- GIN indexes on JSON columns for tag searching
- Partial indexes for common filtered queries

---

## Data Access Patterns

### Common Query Patterns

#### 1. Teacher Dashboard View
```sql
-- Get teacher's students
SELECT * FROM Students 
WHERE teacher_id = ? AND is_active = true;

-- Get today's events
SELECT e.*, et.name as event_type_name
FROM Calendar_Events e
LEFT JOIN Event_Types et ON e.event_type_id = et.id
WHERE e.teacher_id = ? 
  AND DATE(e.start_time) = CURRENT_DATE
ORDER BY e.start_time;

-- Get pending tasks
SELECT * FROM Tasks
WHERE teacher_id = ? 
  AND status IN ('pending', 'in_progress')
ORDER BY due_date ASC NULLS LAST;
```

#### 2. Student Profile View
```sql
-- Get student with teacher info
SELECT s.*, t.first_name as teacher_first_name, t.last_name as teacher_last_name
FROM Students s
JOIN Teachers t ON s.teacher_id = t.id
WHERE s.id = ?;

-- Get student's upcoming assignments
SELECT a.*, sub.name as subject_name
FROM Assignments a
LEFT JOIN Subjects sub ON a.subject_id = sub.id
WHERE a.student_id = ?
  AND a.completion_status != 'completed'
ORDER BY a.due_date ASC NULLS LAST
LIMIT 10;

-- Get student's schedule for week
SELECT ce.*, et.name as event_type_name
FROM Calendar_Events ce
JOIN Event_Attendees ea ON ce.id = ea.event_id
LEFT JOIN Event_Types et ON ce.event_type_id = et.id
WHERE ea.student_id = ?
  AND ce.start_time BETWEEN ? AND ?
ORDER BY ce.start_time;
```

#### 3. Report Card Generation
```sql
-- Get report card with entries
SELECT rc.*, rce.*, s.name as subject_name
FROM Report_Cards rc
LEFT JOIN Report_Card_Entries rce ON rc.id = rce.report_card_id
LEFT JOIN Subjects s ON rce.subject_id = s.id
WHERE rc.id = ?;

-- Get assignments for report card period
SELECT a.*, sub.name as subject_name
FROM Assignments a
LEFT JOIN Subjects sub ON a.subject_id = sub.id
WHERE a.student_id = ?
  AND a.assigned_date BETWEEN ? AND ?
  AND a.completion_status = 'completed';
```

#### 4. Expense Reports
```sql
-- Get expenses by date range
SELECT e.*, ec.name as category_name, s.first_name as student_first_name
FROM Expenses e
LEFT JOIN Expense_Categories ec ON e.category_id = ec.id
LEFT JOIN Students s ON e.student_id = s.id
WHERE e.teacher_id = ?
  AND e.expense_date BETWEEN ? AND ?
ORDER BY e.expense_date DESC;

-- Get expense summary for student and subject
SELECT 
  s.first_name || ' ' || s.last_name as student_name,
  sub.name as subject_name,
  SUM(e.amount) as total_amount,
  COUNT(e.id) as expense_count
FROM Expenses e
LEFT JOIN Students s ON e.student_id = s.id
LEFT JOIN Subjects sub ON e.subject_id = sub.id
WHERE e.teacher_id = ?
  AND e.expense_date BETWEEN ? AND ?
GROUP BY s.id, sub.id;

-- Get monthly expense totals
SELECT 
  DATE_TRUNC('month', expense_date) as month,
  ec.name as category,
  SUM(amount) as total
FROM Expenses e
LEFT JOIN Expense_Categories ec ON e.category_id = ec.id
WHERE e.teacher_id = ?
  AND EXTRACT(YEAR FROM expense_date) = ?
GROUP BY month, ec.name
ORDER BY month, ec.name;
```

#### 5. Lesson Plan Discovery (Public)
```sql
-- Get public lesson plans
SELECT lp.*, t.first_name || ' ' || t.last_name as author_name,
       sub.name as subject_name
FROM Lesson_Plans lp
JOIN Teachers t ON lp.teacher_id = t.id
LEFT JOIN Subjects sub ON lp.subject_id = sub.id
WHERE lp.visibility = 'public'
ORDER BY lp.view_count DESC, lp.created_at DESC
LIMIT 20;

-- Get lesson plans shared with me
SELECT lp.*, t.first_name || ' ' || t.last_name as shared_by_name
FROM Lesson_Plans lp
JOIN Shared_Lesson_Plans slp ON lp.id = slp.lesson_plan_id
JOIN Teachers t ON slp.shared_by_teacher_id = t.id
WHERE slp.shared_with_teacher_id = ?
  AND slp.share_type = 'private'
ORDER BY slp.shared_date DESC;
```

---

## Future Considerations

### Phase 2 Features (Co-op & Multi-Teacher)

When implementing co-op features in v2.0, consider:

1. **Multi-Teacher Support:**
   - Modify Student table to support many-to-many relationship with Teachers
   - Create `Student_Teachers` junction table
   - Add `primary_teacher_id` to Students for main contact

2. **Co-op Groups:**
   - Add `Groups` table for co-op organizations
   - Add `Group_Members` for teacher membership
   - Add `group_id` to Calendar_Events for co-op events

3. **Shared Resources:**
   - Enhance lesson plan sharing with group visibility
   - Add shared expense pools for co-op activities
   - Implement group calendars

### Scalability Considerations

1. **Archiving Strategy:**
   - Add `archived` flag to major tables
   - Implement soft deletes for historical data
   - Create archive tables for old report cards and assignments

2. **Performance Optimization:**
   - Implement caching layer for frequently accessed data
   - Consider read replicas for report generation
   - Add database partitioning for large tables (Expenses, Calendar_Events)

3. **Audit Trail:**
   - Add `updated_by` fields to track changes
   - Consider separate audit log tables for compliance
   - Implement change history for report cards

### Data Migration & Backup

1. **Backup Strategy:**
   - Daily automated backups
   - Point-in-time recovery capability
   - Test restore procedures regularly

2. **Version Control:**
   - Track schema versions
   - Document all migration scripts
   - Implement rollback procedures

---

## Appendix

### Enum Definitions

```sql
-- Completion Status
ENUM completion_status ('not_started', 'in_progress', 'completed', 'overdue')

-- Task Status
ENUM task_status ('pending', 'in_progress', 'completed', 'cancelled')

-- Task Priority
ENUM task_priority ('low', 'medium', 'high')

-- Report Card Status
ENUM report_status ('draft', 'finalized', 'published')

-- Grading System
ENUM grading_system ('letter', 'percentage', 'standards')

-- Share Type
ENUM share_type ('private', 'public')

-- Visibility
ENUM visibility ('private', 'public')

-- Connection Status
ENUM connection_status ('pending', 'accepted', 'blocked')

-- Attendance Status
ENUM attendance_status ('pending', 'attended', 'absent', 'excused')
```

### Sample Data Examples

**Sample Teacher:**
```json
{
  "id": "uuid-123",
  "first_name": "Sarah",
  "last_name": "Johnson",
  "email": "sarah.johnson@email.com",
  "phone": "555-123-4567",
  "newsletter_subscribed": true
}
```

**Sample Student:**
```json
{
  "id": "uuid-456",
  "teacher_id": "uuid-123",
  "first_name": "Emma",
  "last_name": "Johnson",
  "nickname": "Em",
  "grade_level": "5th Grade",
  "date_of_birth": "2015-03-15"
}
```

**Sample Calendar Event:**
```json
{
  "id": "uuid-789",
  "teacher_id": "uuid-123",
  "title": "Math Lesson - Fractions",
  "event_type_id": "uuid-event-type-1",
  "start_time": "2025-11-15T10:00:00Z",
  "end_time": "2025-11-15T11:00:00Z",
  "recurrence_rule": "FREQ=WEEKLY;BYDAY=MO,WE,FR",
  "is_recurring": true
}
```

**Sample Expense:**
```json
{
  "id": "uuid-expense-1",
  "teacher_id": "uuid-123",
  "student_id": "uuid-456",
  "subject_id": "uuid-subject-math",
  "category_id": "uuid-cat-curriculum",
  "expense_date": "2025-01-15",
  "amount": 45.99,
  "vendor": "Amazon",
  "description": "Singapore Math Workbook Level 5",
  "receipt_url": "https://storage.example.com/receipts/123.pdf",
  "tags": ["curriculum", "math", "annual"]
}
```

---

## Document Change Log

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-14 | System | Initial database architecture document |

---

## Approval & Sign-off

**Prepared by:** Database Architecture Team  
**Review Date:** 2025-11-14  
**Status:** Draft - Pending Approval

---

**Next Steps:**
1. Review and approve database schema
2. Create database migration scripts
3. Set up development database environment
4. Implement data access layer (DAL/ORM)
5. Create API endpoints based on access patterns
6. Implement backup and recovery procedures

