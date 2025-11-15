# Homeschool Management App - API Specification

**Version:** 1.0  
**Date:** November 14, 2025  
**Status:** Initial Design  
**Base URL:** `https://api.homeschoolapp.com/v1`

---

## Table of Contents
1. [Overview](#overview)
2. [Authentication](#authentication)
3. [API Conventions](#api-conventions)
4. [Error Handling](#error-handling)
5. [Rate Limiting](#rate-limiting)
6. [API Endpoints](#api-endpoints)
   - [Authentication Endpoints](#authentication-endpoints)
   - [Teacher Endpoints](#teacher-endpoints)
   - [Student Endpoints](#student-endpoints)
   - [Calendar Endpoints](#calendar-endpoints)
   - [Assignment Endpoints](#assignment-endpoints)
   - [Task Endpoints](#task-endpoints)
   - [Report Card Endpoints](#report-card-endpoints)
   - [Expense Endpoints](#expense-endpoints)
   - [Subject Endpoints](#subject-endpoints)
   - [Lesson Plan Endpoints](#lesson-plan-endpoints)
7. [Appendix](#appendix)

---

## Overview

### Purpose
This document defines the RESTful API for the Homeschool Management mobile application. The API enables teachers (homeschool parents) to manage students, calendar events, assignments, tasks, report cards, expenses, and lesson plans.

### Design Principles
- **RESTful Architecture** - Standard HTTP methods (GET, POST, PUT, DELETE)
- **JSON Format** - All requests and responses use JSON
- **Stateless** - Each request contains all necessary information
- **Versioned** - API version in URL path (`/v1`)
- **Secure** - HTTPS only, JWT authentication
- **Consistent** - Predictable naming and response structures

### Technical Stack
- **Protocol:** HTTPS only
- **Format:** JSON (application/json)
- **Authentication:** JWT (JSON Web Tokens)
- **Date/Time Format:** ISO 8601 (UTC)
- **Character Encoding:** UTF-8

---

## Authentication

### Authentication Method: JWT (JSON Web Tokens)

The API uses JWT-based authentication with two token types:

1. **Access Token** - Short-lived (1 hour), used for API requests
2. **Refresh Token** - Long-lived (30 days), used to obtain new access tokens

### Token Storage
- **Mobile Apps:** Store in secure platform storage (iOS Keychain, Android KeyStore)
- **Never** store tokens in local storage or unencrypted files

### Authentication Flow

```
1. User registers or logs in
2. Server returns access_token and refresh_token
3. Client stores both tokens securely
4. Client includes access_token in Authorization header for all requests
5. When access_token expires, use refresh_token to get new access_token
6. If refresh_token expires, user must log in again
```

### Including Authentication in Requests

All protected endpoints require the `Authorization` header:

```http
Authorization: Bearer {access_token}
```

**Example:**
```http
GET /api/v1/students
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Token Expiration
- **Access Token:** 1 hour (3600 seconds)
- **Refresh Token:** 30 days (2592000 seconds)

### Security Requirements
- All API requests must use HTTPS
- Passwords must be hashed using bcrypt or argon2
- Tokens should include user ID and role in payload
- Rate limiting on authentication endpoints

---

## API Conventions

### HTTP Methods

| Method | Purpose | Idempotent |
|--------|---------|------------|
| GET | Retrieve resources | Yes |
| POST | Create new resources | No |
| PUT | Update/replace entire resource | Yes |
| PATCH | Partially update resource | No |
| DELETE | Remove resources | Yes |

### Request Headers

**Required for all requests:**
```http
Content-Type: application/json
Accept: application/json
```

**Required for protected endpoints:**
```http
Authorization: Bearer {access_token}
```

### Response Format

All API responses follow this structure:

#### Success Response
```json
{
  "success": true,
  "data": {
    // Response data here
  },
  "meta": {
    // Optional metadata (pagination, counts, etc.)
  }
}
```

#### Error Response
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {
      // Optional additional error details
    }
  }
}
```

### Pagination

For endpoints that return lists, use query parameters:

```http
GET /api/v1/students?page=1&limit=20
```

**Pagination Parameters:**
- `page` - Page number (default: 1)
- `limit` - Items per page (default: 20, max: 100)

**Paginated Response:**
```json
{
  "success": true,
  "data": [...],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "total_pages": 8,
    "has_next": true,
    "has_prev": false
  }
}
```

### Filtering & Sorting

**Filtering:**
```http
GET /api/v1/assignments?student_id=123&status=incomplete
```

**Sorting:**
```http
GET /api/v1/expenses?sort_by=expense_date&sort_order=desc
```

### Date/Time Format

All dates and times use ISO 8601 format in UTC:

- **Date:** `2025-11-14`
- **DateTime:** `2025-11-14T15:30:00Z`
- **DateTime with timezone:** `2025-11-14T15:30:00-05:00`

---

## Error Handling

### HTTP Status Codes

| Code | Meaning | Usage |
|------|---------|-------|
| 200 | OK | Successful GET, PUT, PATCH, DELETE |
| 201 | Created | Successful POST (resource created) |
| 204 | No Content | Successful DELETE with no response body |
| 400 | Bad Request | Invalid request format or parameters |
| 401 | Unauthorized | Missing or invalid authentication token |
| 403 | Forbidden | Valid token but insufficient permissions |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Request conflicts with existing data |
| 422 | Unprocessable Entity | Validation errors |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server-side error |
| 503 | Service Unavailable | Temporary server unavailability |

### Error Response Format

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed for one or more fields",
    "details": {
      "email": ["Email is required", "Email format is invalid"],
      "password": ["Password must be at least 8 characters"]
    }
  }
}
```

### Common Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `UNAUTHORIZED` | 401 | Missing or invalid token |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource not found |
| `VALIDATION_ERROR` | 422 | Input validation failed |
| `DUPLICATE_EMAIL` | 409 | Email already registered |
| `INVALID_CREDENTIALS` | 401 | Wrong email or password |
| `TOKEN_EXPIRED` | 401 | Access token has expired |
| `RATE_LIMIT_EXCEEDED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Server error |

---

## Rate Limiting

### Limits by Endpoint Type

| Endpoint Type | Limit | Window |
|--------------|-------|--------|
| Authentication (login, register) | 5 requests | per 15 minutes |
| Password reset | 3 requests | per hour |
| Standard API requests | 1000 requests | per hour |
| File uploads | 50 requests | per hour |

### Rate Limit Headers

Responses include rate limit information:

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1699564800
```

### Rate Limit Exceeded Response

```json
{
  "success": false,
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Too many requests. Please try again later.",
    "details": {
      "retry_after": 900
    }
  }
}
```

---

## API Endpoints

---

## Authentication Endpoints

### 1. Register New Teacher

Create a new teacher account.

**Endpoint:** `POST /auth/register`

**Authentication:** None (public endpoint)

**Request Body:**
```json
{
  "first_name": "Sarah",
  "last_name": "Johnson",
  "email": "sarah.johnson@email.com",
  "password": "SecurePassword123!",
  "phone": "555-123-4567",
  "newsletter_subscribed": true
}
```

**Validation Rules:**
- `first_name`: Required, 1-100 characters
- `last_name`: Required, 1-100 characters
- `email`: Required, valid email format, unique
- `password`: Required, minimum 8 characters, must include uppercase, lowercase, and number
- `phone`: Optional, valid phone format
- `newsletter_subscribed`: Optional, boolean (default: false)

**Success Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "teacher": {
      "id": "uuid-123",
      "first_name": "Sarah",
      "last_name": "Johnson",
      "email": "sarah.johnson@email.com",
      "phone": "555-123-4567",
      "newsletter_subscribed": true,
      "created_at": "2025-11-14T15:30:00Z"
    },
    "tokens": {
      "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "expires_in": 3600,
      "token_type": "Bearer"
    }
  }
}
```

**Error Responses:**

400 Bad Request - Invalid input
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": {
      "email": ["Email format is invalid"],
      "password": ["Password must be at least 8 characters"]
    }
  }
}
```

409 Conflict - Email already exists
```json
{
  "success": false,
  "error": {
    "code": "DUPLICATE_EMAIL",
    "message": "An account with this email already exists"
  }
}
```

---

### 2. Login

Authenticate and receive access tokens.

**Endpoint:** `POST /auth/login`

**Authentication:** None (public endpoint)

**Request Body:**
```json
{
  "email": "sarah.johnson@email.com",
  "password": "SecurePassword123!"
}
```

**Validation Rules:**
- `email`: Required, valid email format
- `password`: Required

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "teacher": {
      "id": "uuid-123",
      "first_name": "Sarah",
      "last_name": "Johnson",
      "email": "sarah.johnson@email.com",
      "phone": "555-123-4567",
      "newsletter_subscribed": true
    },
    "tokens": {
      "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "expires_in": 3600,
      "token_type": "Bearer"
    }
  }
}
```

**Error Response (401 Unauthorized):**
```json
{
  "success": false,
  "error": {
    "code": "INVALID_CREDENTIALS",
    "message": "Invalid email or password"
  }
}
```

---

### 3. Refresh Access Token

Get a new access token using refresh token.

**Endpoint:** `POST /auth/refresh`

**Authentication:** None (uses refresh token)

**Request Body:**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expires_in": 3600,
    "token_type": "Bearer"
  }
}
```

**Error Response (401 Unauthorized):**
```json
{
  "success": false,
  "error": {
    "code": "TOKEN_EXPIRED",
    "message": "Refresh token has expired. Please log in again."
  }
}
```

---

### 4. Logout

Invalidate current tokens.

**Endpoint:** `POST /auth/logout`

**Authentication:** Required (Bearer token)

**Request Body:**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "message": "Successfully logged out"
  }
}
```

---

### 5. Request Password Reset

Request password reset email.

**Endpoint:** `POST /auth/password/reset-request`

**Authentication:** None (public endpoint)

**Request Body:**
```json
{
  "email": "sarah.johnson@email.com"
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "message": "If an account exists with this email, a password reset link has been sent."
  }
}
```

**Note:** Always return success even if email doesn't exist (security best practice)

---

### 6. Reset Password

Reset password using token from email.

**Endpoint:** `POST /auth/password/reset`

**Authentication:** None (uses reset token)

**Request Body:**
```json
{
  "reset_token": "token-from-email",
  "new_password": "NewSecurePassword123!"
}
```

**Validation Rules:**
- `reset_token`: Required, valid reset token
- `new_password`: Required, minimum 8 characters, must include uppercase, lowercase, and number

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "message": "Password successfully reset. Please log in with your new password."
  }
}
```

**Error Response (400 Bad Request):**
```json
{
  "success": false,
  "error": {
    "code": "INVALID_TOKEN",
    "message": "Reset token is invalid or has expired"
  }
}
```

---

### 7. Change Password

Change password for authenticated user.

**Endpoint:** `POST /auth/password/change`

**Authentication:** Required (Bearer token)

**Request Body:**
```json
{
  "current_password": "SecurePassword123!",
  "new_password": "NewSecurePassword456!"
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "message": "Password successfully changed"
  }
}
```

**Error Response (401 Unauthorized):**
```json
{
  "success": false,
  "error": {
    "code": "INVALID_CREDENTIALS",
    "message": "Current password is incorrect"
  }
}
```

---

### 8. Verify Email

Verify email address using token from verification email.

**Endpoint:** `POST /auth/email/verify`

**Authentication:** None (uses verification token)

**Request Body:**
```json
{
  "verification_token": "token-from-email"
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "message": "Email successfully verified"
  }
}
```

---

### 9. Resend Verification Email

Request a new verification email.

**Endpoint:** `POST /auth/email/resend-verification`

**Authentication:** Required (Bearer token)

**Request Body:** None

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "message": "Verification email sent"
  }
}
```

---

## Teacher Endpoints

### 1. Get Current Teacher Profile

Get authenticated teacher's profile.

**Endpoint:** `GET /teachers/me`

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-123",
    "first_name": "Sarah",
    "last_name": "Johnson",
    "nickname": null,
    "email": "sarah.johnson@email.com",
    "phone": "555-123-4567",
    "newsletter_subscribed": true,
    "profile_image_url": "https://storage.example.com/profiles/uuid-123.jpg",
    "created_at": "2025-01-15T10:00:00Z",
    "updated_at": "2025-11-14T15:30:00Z"
  }
}
```

---

### 2. Update Teacher Profile

Update authenticated teacher's profile.

**Endpoint:** `PUT /teachers/me`

**Authentication:** Required

**Request Body:**
```json
{
  "first_name": "Sarah",
  "last_name": "Johnson",
  "nickname": "Ms. J",
  "phone": "555-123-4567",
  "newsletter_subscribed": false
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-123",
    "first_name": "Sarah",
    "last_name": "Johnson",
    "nickname": "Ms. J",
    "email": "sarah.johnson@email.com",
    "phone": "555-123-4567",
    "newsletter_subscribed": false,
    "updated_at": "2025-11-14T16:00:00Z"
  }
}
```

---

### 3. Upload Profile Image

Upload or update teacher profile image.

**Endpoint:** `POST /teachers/me/profile-image`

**Authentication:** Required

**Content-Type:** `multipart/form-data`

**Request Body:**
```
file: [image file] (JPEG, PNG, max 5MB)
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "profile_image_url": "https://storage.example.com/profiles/uuid-123.jpg",
    "uploaded_at": "2025-11-14T16:00:00Z"
  }
}
```

---

### 4. Delete Teacher Account

Permanently delete teacher account and all associated data.

**Endpoint:** `DELETE /teachers/me`

**Authentication:** Required

**Request Body:**
```json
{
  "password": "SecurePassword123!",
  "confirmation": "DELETE"
}
```

**Success Response (204 No Content)**

---

## Student Endpoints

### 1. Get All Students

Get all students for authenticated teacher.

**Endpoint:** `GET /students`

**Authentication:** Required

**Query Parameters:**
- `is_active` (optional): Filter by active status (true/false)
- `grade_level` (optional): Filter by grade level
- `sort_by` (optional): Field to sort by (default: first_name)
- `sort_order` (optional): asc or desc (default: asc)

**Example Request:**
```http
GET /students?is_active=true&sort_by=first_name&sort_order=asc
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid-456",
      "teacher_id": "uuid-123",
      "first_name": "Emma",
      "last_name": "Johnson",
      "nickname": "Em",
      "date_of_birth": "2015-03-15",
      "grade_level": "5th Grade",
      "profile_image_url": "https://storage.example.com/students/uuid-456.jpg",
      "notes": "Advanced in math, loves science",
      "is_active": true,
      "created_at": "2025-01-15T10:00:00Z",
      "updated_at": "2025-11-14T15:30:00Z"
    },
    {
      "id": "uuid-789",
      "teacher_id": "uuid-123",
      "first_name": "Jack",
      "last_name": "Johnson",
      "nickname": null,
      "date_of_birth": "2018-07-22",
      "grade_level": "2nd Grade",
      "profile_image_url": null,
      "notes": null,
      "is_active": true,
      "created_at": "2025-01-15T10:05:00Z",
      "updated_at": "2025-11-14T15:30:00Z"
    }
  ],
  "meta": {
    "total": 2
  }
}
```

---

### 2. Get Single Student

Get details for a specific student.

**Endpoint:** `GET /students/{student_id}`

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-456",
    "teacher_id": "uuid-123",
    "first_name": "Emma",
    "last_name": "Johnson",
    "nickname": "Em",
    "date_of_birth": "2015-03-15",
    "grade_level": "5th Grade",
    "profile_image_url": "https://storage.example.com/students/uuid-456.jpg",
    "notes": "Advanced in math, loves science",
    "is_active": true,
    "created_at": "2025-01-15T10:00:00Z",
    "updated_at": "2025-11-14T15:30:00Z"
  }
}
```

**Error Response (404 Not Found):**
```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "Student not found"
  }
}
```

---

### 3. Create Student

Create a new student.

**Endpoint:** `POST /students`

**Authentication:** Required

**Request Body:**
```json
{
  "first_name": "Emma",
  "last_name": "Johnson",
  "nickname": "Em",
  "date_of_birth": "2015-03-15",
  "grade_level": "5th Grade",
  "notes": "Advanced in math, loves science"
}
```

**Validation Rules:**
- `first_name`: Required, 1-100 characters
- `last_name`: Required, 1-100 characters
- `nickname`: Optional, max 100 characters
- `date_of_birth`: Optional, valid date (YYYY-MM-DD)
- `grade_level`: Optional, max 20 characters
- `notes`: Optional, text

**Success Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-456",
    "teacher_id": "uuid-123",
    "first_name": "Emma",
    "last_name": "Johnson",
    "nickname": "Em",
    "date_of_birth": "2015-03-15",
    "grade_level": "5th Grade",
    "profile_image_url": null,
    "notes": "Advanced in math, loves science",
    "is_active": true,
    "created_at": "2025-11-14T16:00:00Z",
    "updated_at": "2025-11-14T16:00:00Z"
  }
}
```

---

### 4. Update Student

Update student information.

**Endpoint:** `PUT /students/{student_id}`

**Authentication:** Required

**Request Body:**
```json
{
  "first_name": "Emma",
  "last_name": "Johnson",
  "nickname": "Emma J",
  "date_of_birth": "2015-03-15",
  "grade_level": "6th Grade",
  "notes": "Advanced in math and science"
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-456",
    "teacher_id": "uuid-123",
    "first_name": "Emma",
    "last_name": "Johnson",
    "nickname": "Emma J",
    "date_of_birth": "2015-03-15",
    "grade_level": "6th Grade",
    "profile_image_url": "https://storage.example.com/students/uuid-456.jpg",
    "notes": "Advanced in math and science",
    "is_active": true,
    "updated_at": "2025-11-14T16:30:00Z"
  }
}
```

---

### 5. Delete Student

Soft delete or permanently delete a student.

**Endpoint:** `DELETE /students/{student_id}`

**Authentication:** Required

**Query Parameters:**
- `permanent` (optional): true for hard delete, false for soft delete (default: false)

**Success Response (204 No Content)**

---

### 6. Upload Student Profile Image

Upload or update student profile image.

**Endpoint:** `POST /students/{student_id}/profile-image`

**Authentication:** Required

**Content-Type:** `multipart/form-data`

**Request Body:**
```
file: [image file] (JPEG, PNG, max 5MB)
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "profile_image_url": "https://storage.example.com/students/uuid-456.jpg",
    "uploaded_at": "2025-11-14T16:00:00Z"
  }
}
```

---

## Calendar Endpoints

### 1. Get Calendar Events

Get calendar events for authenticated teacher.

**Endpoint:** `GET /calendar/events`

**Authentication:** Required

**Query Parameters:**
- `start_date` (optional): Start of date range (ISO 8601)
- `end_date` (optional): End of date range (ISO 8601)
- `student_id` (optional): Filter by student
- `event_type_id` (optional): Filter by event type
- `include_recurring` (optional): Include recurring events (default: true)
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 50)

**Example Request:**
```http
GET /calendar/events?start_date=2025-11-01&end_date=2025-11-30&student_id=uuid-456
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid-event-1",
      "teacher_id": "uuid-123",
      "event_type_id": "uuid-type-1",
      "event_type_name": "Lesson",
      "title": "Math - Fractions",
      "description": "Introduction to fractions with visual aids",
      "location": "Home classroom",
      "start_time": "2025-11-15T10:00:00Z",
      "end_time": "2025-11-15T11:00:00Z",
      "all_day": false,
      "is_recurring": true,
      "recurrence_rule": "FREQ=WEEKLY;BYDAY=MO,WE,FR",
      "recurrence_end_date": "2025-12-20",
      "parent_event_id": null,
      "color_code": "#4CAF50",
      "reminder_minutes": 30,
      "attendees": [
        {
          "student_id": "uuid-456",
          "student_name": "Emma Johnson",
          "attendance_status": "pending"
        }
      ],
      "created_at": "2025-11-01T10:00:00Z",
      "updated_at": "2025-11-01T10:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "limit": 50,
    "total": 1
  }
}
```

---

### 2. Get Single Calendar Event

Get details for a specific event.

**Endpoint:** `GET /calendar/events/{event_id}`

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-event-1",
    "teacher_id": "uuid-123",
    "event_type_id": "uuid-type-1",
    "event_type_name": "Lesson",
    "title": "Math - Fractions",
    "description": "Introduction to fractions with visual aids",
    "location": "Home classroom",
    "start_time": "2025-11-15T10:00:00Z",
    "end_time": "2025-11-15T11:00:00Z",
    "all_day": false,
    "is_recurring": true,
    "recurrence_rule": "FREQ=WEEKLY;BYDAY=MO,WE,FR",
    "recurrence_end_date": "2025-12-20",
    "parent_event_id": null,
    "color_code": "#4CAF50",
    "reminder_minutes": 30,
    "attendees": [
      {
        "student_id": "uuid-456",
        "student_name": "Emma Johnson",
        "attendance_status": "pending"
      }
    ],
    "created_at": "2025-11-01T10:00:00Z",
    "updated_at": "2025-11-01T10:00:00Z"
  }
}
```

---

### 3. Create Calendar Event

Create a new calendar event.

**Endpoint:** `POST /calendar/events`

**Authentication:** Required

**Request Body:**
```json
{
  "event_type_id": "uuid-type-1",
  "title": "Math - Fractions",
  "description": "Introduction to fractions with visual aids",
  "location": "Home classroom",
  "start_time": "2025-11-15T10:00:00Z",
  "end_time": "2025-11-15T11:00:00Z",
  "all_day": false,
  "is_recurring": true,
  "recurrence_rule": "FREQ=WEEKLY;BYDAY=MO,WE,FR",
  "recurrence_end_date": "2025-12-20",
  "color_code": "#4CAF50",
  "reminder_minutes": 30,
  "student_ids": ["uuid-456", "uuid-789"]
}
```

**Validation Rules:**
- `title`: Required, max 255 characters
- `start_time`: Required, valid ISO 8601 datetime
- `end_time`: Optional, must be after start_time
- `all_day`: Optional, boolean (default: false)
- `is_recurring`: Optional, boolean (default: false)
- `recurrence_rule`: Required if is_recurring=true, valid RRULE format
- `student_ids`: Optional, array of valid student IDs

**Success Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-event-1",
    "teacher_id": "uuid-123",
    "event_type_id": "uuid-type-1",
    "title": "Math - Fractions",
    "description": "Introduction to fractions with visual aids",
    "location": "Home classroom",
    "start_time": "2025-11-15T10:00:00Z",
    "end_time": "2025-11-15T11:00:00Z",
    "all_day": false,
    "is_recurring": true,
    "recurrence_rule": "FREQ=WEEKLY;BYDAY=MO,WE,FR",
    "recurrence_end_date": "2025-12-20",
    "color_code": "#4CAF50",
    "reminder_minutes": 30,
    "attendees": [
      {
        "student_id": "uuid-456",
        "student_name": "Emma Johnson"
      }
    ],
    "created_at": "2025-11-14T16:00:00Z"
  }
}
```

---

### 4. Update Calendar Event

Update an existing calendar event.

**Endpoint:** `PUT /calendar/events/{event_id}`

**Authentication:** Required

**Request Body:**
```json
{
  "title": "Math - Advanced Fractions",
  "description": "Continuing fractions lesson",
  "start_time": "2025-11-15T10:30:00Z",
  "end_time": "2025-11-15T11:30:00Z",
  "reminder_minutes": 15,
  "student_ids": ["uuid-456"]
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-event-1",
    "title": "Math - Advanced Fractions",
    "updated_at": "2025-11-14T16:30:00Z"
  }
}
```

---

### 5. Delete Calendar Event

Delete a calendar event (with option to delete recurring series).

**Endpoint:** `DELETE /calendar/events/{event_id}`

**Authentication:** Required

**Query Parameters:**
- `delete_series` (optional): Delete entire recurring series (default: false)

**Success Response (204 No Content)**

---

### 6. Update Event Attendance

Update attendance status for a student in an event.

**Endpoint:** `PATCH /calendar/events/{event_id}/attendance/{student_id}`

**Authentication:** Required

**Request Body:**
```json
{
  "attendance_status": "attended"
}
```

**Validation Rules:**
- `attendance_status`: Required, one of: pending, attended, absent, excused

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "event_id": "uuid-event-1",
    "student_id": "uuid-456",
    "attendance_status": "attended",
    "updated_at": "2025-11-15T11:30:00Z"
  }
}
```

---

### 7. Get Event Types

Get all event types available.

**Endpoint:** `GET /calendar/event-types`

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid-type-1",
      "name": "Lesson",
      "color_code": "#4CAF50",
      "icon": "book",
      "description": "Regular lesson or teaching session",
      "is_system_default": true
    },
    {
      "id": "uuid-type-2",
      "name": "Field Trip",
      "color_code": "#2196F3",
      "icon": "bus",
      "description": "Educational field trip or outing",
      "is_system_default": true
    }
  ]
}
```

---

### 8. Create Custom Event Type

Create a custom event type.

**Endpoint:** `POST /calendar/event-types`

**Authentication:** Required

**Request Body:**
```json
{
  "name": "Music Practice",
  "color_code": "#9C27B0",
  "icon": "music",
  "description": "Daily music practice session"
}
```

**Success Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-type-custom-1",
    "name": "Music Practice",
    "color_code": "#9C27B0",
    "icon": "music",
    "description": "Daily music practice session",
    "is_system_default": false
  }
}
```

---

## Assignment Endpoints

### 1. Get All Assignments

Get assignments for authenticated teacher.

**Endpoint:** `GET /assignments`

**Authentication:** Required

**Query Parameters:**
- `student_id` (optional): Filter by student
- `subject_id` (optional): Filter by subject
- `completion_status` (optional): Filter by status (not_started, in_progress, completed, overdue)
- `due_date_from` (optional): Assignments due after this date
- `due_date_to` (optional): Assignments due before this date
- `sort_by` (optional): Field to sort by (default: due_date)
- `sort_order` (optional): asc or desc (default: asc)
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 20)

**Example Request:**
```http
GET /assignments?student_id=uuid-456&completion_status=incomplete&sort_by=due_date
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid-assign-1",
      "student_id": "uuid-456",
      "student_name": "Emma Johnson",
      "teacher_id": "uuid-123",
      "subject_id": "uuid-subject-1",
      "subject_name": "Mathematics",
      "calendar_event_id": "uuid-event-1",
      "title": "Fractions Worksheet #1",
      "description": "Complete pages 15-18 in the workbook",
      "due_date": "2025-11-20T23:59:59Z",
      "assigned_date": "2025-11-14",
      "completion_status": "not_started",
      "completed_date": null,
      "grade": null,
      "points_earned": null,
      "points_possible": 100,
      "notes": null,
      "attachments": [
        {
          "name": "worksheet.pdf",
          "url": "https://storage.example.com/assignments/worksheet.pdf",
          "type": "pdf",
          "size": 245678
        }
      ],
      "created_at": "2025-11-14T10:00:00Z",
      "updated_at": "2025-11-14T10:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 1
  }
}
```

---

### 2. Get Single Assignment

Get details for a specific assignment.

**Endpoint:** `GET /assignments/{assignment_id}`

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-assign-1",
    "student_id": "uuid-456",
    "student_name": "Emma Johnson",
    "teacher_id": "uuid-123",
    "subject_id": "uuid-subject-1",
    "subject_name": "Mathematics",
    "calendar_event_id": "uuid-event-1",
    "title": "Fractions Worksheet #1",
    "description": "Complete pages 15-18 in the workbook",
    "due_date": "2025-11-20T23:59:59Z",
    "assigned_date": "2025-11-14",
    "completion_status": "not_started",
    "completed_date": null,
    "grade": null,
    "points_earned": null,
    "points_possible": 100,
    "notes": null,
    "attachments": [],
    "created_at": "2025-11-14T10:00:00Z",
    "updated_at": "2025-11-14T10:00:00Z"
  }
}
```

---

### 3. Create Assignment

Create a new assignment.

**Endpoint:** `POST /assignments`

**Authentication:** Required

**Request Body:**
```json
{
  "student_id": "uuid-456",
  "subject_id": "uuid-subject-1",
  "calendar_event_id": "uuid-event-1",
  "title": "Fractions Worksheet #1",
  "description": "Complete pages 15-18 in the workbook",
  "due_date": "2025-11-20T23:59:59Z",
  "assigned_date": "2025-11-14",
  "points_possible": 100,
  "notes": "Focus on proper notation"
}
```

**Validation Rules:**
- `student_id`: Required, valid student ID
- `title`: Required, max 255 characters
- `subject_id`: Optional, valid subject ID
- `calendar_event_id`: Optional, valid event ID
- `due_date`: Optional, valid ISO 8601 datetime
- `assigned_date`: Required, valid date (YYYY-MM-DD)
- `points_possible`: Optional, positive decimal

**Success Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-assign-1",
    "student_id": "uuid-456",
    "teacher_id": "uuid-123",
    "subject_id": "uuid-subject-1",
    "title": "Fractions Worksheet #1",
    "completion_status": "not_started",
    "created_at": "2025-11-14T16:00:00Z"
  }
}
```

---

### 4. Update Assignment

Update an existing assignment.

**Endpoint:** `PUT /assignments/{assignment_id}`

**Authentication:** Required

**Request Body:**
```json
{
  "title": "Fractions Worksheet #1 (Revised)",
  "due_date": "2025-11-22T23:59:59Z",
  "completion_status": "in_progress",
  "grade": "A-",
  "points_earned": 92.5,
  "notes": "Great work on problems 1-10"
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-assign-1",
    "title": "Fractions Worksheet #1 (Revised)",
    "due_date": "2025-11-22T23:59:59Z",
    "completion_status": "in_progress",
    "grade": "A-",
    "points_earned": 92.5,
    "updated_at": "2025-11-14T16:30:00Z"
  }
}
```

---

### 5. Mark Assignment Complete

Mark an assignment as completed.

**Endpoint:** `PATCH /assignments/{assignment_id}/complete`

**Authentication:** Required

**Request Body:**
```json
{
  "completed_date": "2025-11-18T14:30:00Z",
  "grade": "A",
  "points_earned": 98,
  "notes": "Excellent work!"
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-assign-1",
    "completion_status": "completed",
    "completed_date": "2025-11-18T14:30:00Z",
    "grade": "A",
    "points_earned": 98
  }
}
```

---

### 6. Delete Assignment

Delete an assignment.

**Endpoint:** `DELETE /assignments/{assignment_id}`

**Authentication:** Required

**Success Response (204 No Content)**

---

### 7. Upload Assignment Attachment

Upload a file attachment to an assignment.

**Endpoint:** `POST /assignments/{assignment_id}/attachments`

**Authentication:** Required

**Content-Type:** `multipart/form-data`

**Request Body:**
```
file: [file] (PDF, DOCX, images, max 10MB)
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "attachment": {
      "name": "worksheet.pdf",
      "url": "https://storage.example.com/assignments/worksheet.pdf",
      "type": "pdf",
      "size": 245678,
      "uploaded_at": "2025-11-14T16:00:00Z"
    }
  }
}
```

---

### 8. Delete Assignment Attachment

Delete a file attachment from an assignment.

**Endpoint:** `DELETE /assignments/{assignment_id}/attachments/{attachment_id}`

**Authentication:** Required

**Success Response (204 No Content)**

---

## Task Endpoints

### 1. Get All Tasks

Get tasks for authenticated teacher.

**Endpoint:** `GET /tasks`

**Authentication:** Required

**Query Parameters:**
- `student_id` (optional): Filter by student (null for teacher-only tasks)
- `status` (optional): Filter by status (pending, in_progress, completed, cancelled)
- `priority` (optional): Filter by priority (low, medium, high)
- `due_date_from` (optional): Tasks due after this date
- `due_date_to` (optional): Tasks due before this date
- `category` (optional): Filter by category
- `sort_by` (optional): Field to sort by (default: due_date)
- `sort_order` (optional): asc or desc (default: asc)
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 20)

**Example Request:**
```http
GET /tasks?status=pending&priority=high&sort_by=due_date
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid-task-1",
      "teacher_id": "uuid-123",
      "student_id": null,
      "title": "Order new curriculum books",
      "description": "Order math books for next semester from Amazon",
      "due_date": "2025-11-30T23:59:59Z",
      "priority": "high",
      "status": "pending",
      "completed_date": null,
      "category": "Shopping",
      "created_at": "2025-11-14T10:00:00Z",
      "updated_at": "2025-11-14T10:00:00Z"
    },
    {
      "id": "uuid-task-2",
      "teacher_id": "uuid-123",
      "student_id": "uuid-456",
      "student_name": "Emma Johnson",
      "title": "Science project presentation",
      "description": "Practice presentation for volcano project",
      "due_date": "2025-11-18T10:00:00Z",
      "priority": "medium",
      "status": "in_progress",
      "completed_date": null,
      "category": "Projects",
      "created_at": "2025-11-13T15:00:00Z",
      "updated_at": "2025-11-14T09:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 2
  }
}
```

---

### 2. Get Single Task

Get details for a specific task.

**Endpoint:** `GET /tasks/{task_id}`

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-task-1",
    "teacher_id": "uuid-123",
    "student_id": null,
    "title": "Order new curriculum books",
    "description": "Order math books for next semester from Amazon",
    "due_date": "2025-11-30T23:59:59Z",
    "priority": "high",
    "status": "pending",
    "completed_date": null,
    "category": "Shopping",
    "created_at": "2025-11-14T10:00:00Z",
    "updated_at": "2025-11-14T10:00:00Z"
  }
}
```

---

### 3. Create Task

Create a new task.

**Endpoint:** `POST /tasks`

**Authentication:** Required

**Request Body:**
```json
{
  "student_id": null,
  "title": "Order new curriculum books",
  "description": "Order math books for next semester from Amazon",
  "due_date": "2025-11-30T23:59:59Z",
  "priority": "high",
  "category": "Shopping"
}
```

**Validation Rules:**
- `title`: Required, max 255 characters
- `student_id`: Optional, null for teacher-only task
- `description`: Optional, text
- `due_date`: Optional, valid ISO 8601 datetime
- `priority`: Optional, one of: low, medium, high (default: medium)
- `category`: Optional, max 100 characters

**Success Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-task-1",
    "teacher_id": "uuid-123",
    "student_id": null,
    "title": "Order new curriculum books",
    "status": "pending",
    "priority": "high",
    "created_at": "2025-11-14T16:00:00Z"
  }
}
```

---

### 4. Update Task

Update an existing task.

**Endpoint:** `PUT /tasks/{task_id}`

**Authentication:** Required

**Request Body:**
```json
{
  "title": "Order new curriculum books (Updated)",
  "status": "in_progress",
  "priority": "medium",
  "due_date": "2025-12-05T23:59:59Z"
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-task-1",
    "title": "Order new curriculum books (Updated)",
    "status": "in_progress",
    "priority": "medium",
    "due_date": "2025-12-05T23:59:59Z",
    "updated_at": "2025-11-14T16:30:00Z"
  }
}
```

---

### 5. Mark Task Complete

Mark a task as completed.

**Endpoint:** `PATCH /tasks/{task_id}/complete`

**Authentication:** Required

**Request Body:**
```json
{
  "completed_date": "2025-11-14T17:00:00Z"
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-task-1",
    "status": "completed",
    "completed_date": "2025-11-14T17:00:00Z"
  }
}
```

---

### 6. Delete Task

Delete a task.

**Endpoint:** `DELETE /tasks/{task_id}`

**Authentication:** Required

**Success Response (204 No Content)**

---

## Report Card Endpoints

### 1. Get All Report Cards

Get report cards for authenticated teacher.

**Endpoint:** `GET /report-cards`

**Authentication:** Required

**Query Parameters:**
- `student_id` (optional): Filter by student
- `period_type` (optional): Filter by period type
- `status` (optional): Filter by status (draft, finalized, published)
- `year` (optional): Filter by year
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 20)

**Example Request:**
```http
GET /report-cards?student_id=uuid-456&status=finalized
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid-rc-1",
      "student_id": "uuid-456",
      "student_name": "Emma Johnson",
      "teacher_id": "uuid-123",
      "title": "Q1 2025 Report Card",
      "period_type": "quarterly",
      "start_date": "2025-09-01",
      "end_date": "2025-11-30",
      "grading_system": "letter",
      "status": "finalized",
      "overall_comments": "Excellent progress this quarter!",
      "created_at": "2025-11-01T10:00:00Z",
      "updated_at": "2025-11-14T15:00:00Z",
      "published_at": "2025-11-14T15:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 1
  }
}
```

---

### 2. Get Single Report Card

Get details for a specific report card with all entries.

**Endpoint:** `GET /report-cards/{report_card_id}`

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-rc-1",
    "student_id": "uuid-456",
    "student_name": "Emma Johnson",
    "teacher_id": "uuid-123",
    "title": "Q1 2025 Report Card",
    "period_type": "quarterly",
    "start_date": "2025-09-01",
    "end_date": "2025-11-30",
    "grading_system": "letter",
    "status": "finalized",
    "overall_comments": "Excellent progress this quarter!",
    "entries": [
      {
        "id": "uuid-entry-1",
        "report_card_id": "uuid-rc-1",
        "subject_id": "uuid-subject-1",
        "subject_name": "Mathematics",
        "letter_grade": "A",
        "percentage_grade": null,
        "standards_rating": null,
        "comments": "Excellent understanding of fractions and decimals",
        "created_at": "2025-11-14T14:00:00Z",
        "updated_at": "2025-11-14T14:30:00Z"
      },
      {
        "id": "uuid-entry-2",
        "report_card_id": "uuid-rc-1",
        "subject_id": "uuid-subject-2",
        "subject_name": "Science",
        "letter_grade": "A-",
        "percentage_grade": null,
        "standards_rating": null,
        "comments": "Strong lab skills and scientific thinking",
        "created_at": "2025-11-14T14:00:00Z",
        "updated_at": "2025-11-14T14:30:00Z"
      }
    ],
    "created_at": "2025-11-01T10:00:00Z",
    "updated_at": "2025-11-14T15:00:00Z",
    "published_at": "2025-11-14T15:00:00Z"
  }
}
```

---

### 3. Create Report Card

Create a new report card.

**Endpoint:** `POST /report-cards`

**Authentication:** Required

**Request Body:**
```json
{
  "student_id": "uuid-456",
  "title": "Q2 2025 Report Card",
  "period_type": "quarterly",
  "start_date": "2025-12-01",
  "end_date": "2026-02-28",
  "grading_system": "letter",
  "overall_comments": "Looking forward to continued growth"
}
```

**Validation Rules:**
- `student_id`: Required, valid student ID
- `title`: Required, max 255 characters
- `period_type`: Required, one of: weekly, monthly, quarterly, semester, annual, custom
- `start_date`: Required, valid date (YYYY-MM-DD)
- `end_date`: Required, valid date, must be after start_date
- `grading_system`: Required, one of: letter, percentage, standards

**Success Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-rc-2",
    "student_id": "uuid-456",
    "teacher_id": "uuid-123",
    "title": "Q2 2025 Report Card",
    "period_type": "quarterly",
    "start_date": "2025-12-01",
    "end_date": "2026-02-28",
    "grading_system": "letter",
    "status": "draft",
    "created_at": "2025-11-14T16:00:00Z"
  }
}
```

---

### 4. Update Report Card

Update report card information.

**Endpoint:** `PUT /report-cards/{report_card_id}`

**Authentication:** Required

**Request Body:**
```json
{
  "title": "Q2 2025 Report Card (Updated)",
  "overall_comments": "Strong academic progress this quarter",
  "status": "finalized"
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-rc-2",
    "title": "Q2 2025 Report Card (Updated)",
    "overall_comments": "Strong academic progress this quarter",
    "status": "finalized",
    "published_at": "2025-11-14T16:30:00Z",
    "updated_at": "2025-11-14T16:30:00Z"
  }
}
```

---

### 5. Add/Update Report Card Entry

Add or update a subject entry in a report card.

**Endpoint:** `POST /report-cards/{report_card_id}/entries`

**Authentication:** Required

**Request Body:**
```json
{
  "subject_id": "uuid-subject-1",
  "subject_name": "Mathematics",
  "letter_grade": "A",
  "percentage_grade": null,
  "standards_rating": null,
  "comments": "Excellent understanding of fractions and decimals"
}
```

**Validation Rules:**
- `subject_name`: Required, max 100 characters
- `letter_grade`: Optional, max 5 characters (for letter grading system)
- `percentage_grade`: Optional, 0-100 (for percentage grading system)
- `standards_rating`: Optional, max 50 characters (for standards-based grading)

**Success Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-entry-1",
    "report_card_id": "uuid-rc-1",
    "subject_id": "uuid-subject-1",
    "subject_name": "Mathematics",
    "letter_grade": "A",
    "comments": "Excellent understanding of fractions and decimals",
    "created_at": "2025-11-14T16:00:00Z"
  }
}
```

---

### 6. Delete Report Card Entry

Delete a subject entry from a report card.

**Endpoint:** `DELETE /report-cards/{report_card_id}/entries/{entry_id}`

**Authentication:** Required

**Success Response (204 No Content)**

---

### 7. Delete Report Card

Delete an entire report card.

**Endpoint:** `DELETE /report-cards/{report_card_id}`

**Authentication:** Required

**Success Response (204 No Content)**

---

### 8. Generate Report Card PDF

Generate a PDF version of the report card.

**Endpoint:** `POST /report-cards/{report_card_id}/pdf`

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "pdf_url": "https://storage.example.com/report-cards/uuid-rc-1.pdf",
    "generated_at": "2025-11-14T16:00:00Z",
    "expires_at": "2025-11-21T16:00:00Z"
  }
}
```

---

## Expense Endpoints

### 1. Get All Expenses

Get expenses for authenticated teacher.

**Endpoint:** `GET /expenses`

**Authentication:** Required

**Query Parameters:**
- `student_id` (optional): Filter by student (null for general expenses)
- `subject_id` (optional): Filter by subject
- `category_id` (optional): Filter by category
- `expense_date_from` (optional): Expenses after this date
- `expense_date_to` (optional): Expenses before this date
- `is_tax_deductible` (optional): Filter by tax deductible status
- `tags` (optional): Filter by tags (comma-separated)
- `sort_by` (optional): Field to sort by (default: expense_date)
- `sort_order` (optional): asc or desc (default: desc)
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 20)

**Example Request:**
```http
GET /expenses?student_id=uuid-456&expense_date_from=2025-01-01&expense_date_to=2025-01-31
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid-expense-1",
      "teacher_id": "uuid-123",
      "student_id": "uuid-456",
      "student_name": "Emma Johnson",
      "subject_id": "uuid-subject-1",
      "subject_name": "Mathematics",
      "category_id": "uuid-cat-1",
      "category_name": "Curriculum",
      "expense_date": "2025-01-15",
      "amount": 45.99,
      "currency": "USD",
      "vendor": "Amazon",
      "description": "Singapore Math Workbook Level 5",
      "receipt_url": "https://storage.example.com/receipts/receipt-123.pdf",
      "payment_method": "Credit Card",
      "is_tax_deductible": true,
      "notes": "Annual curriculum purchase",
      "tags": ["curriculum", "math", "annual"],
      "created_at": "2025-01-15T20:00:00Z",
      "updated_at": "2025-01-15T20:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 1,
    "total_amount": 45.99
  }
}
```

---

### 2. Get Single Expense

Get details for a specific expense.

**Endpoint:** `GET /expenses/{expense_id}`

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-expense-1",
    "teacher_id": "uuid-123",
    "student_id": "uuid-456",
    "student_name": "Emma Johnson",
    "subject_id": "uuid-subject-1",
    "subject_name": "Mathematics",
    "category_id": "uuid-cat-1",
    "category_name": "Curriculum",
    "expense_date": "2025-01-15",
    "amount": 45.99,
    "currency": "USD",
    "vendor": "Amazon",
    "description": "Singapore Math Workbook Level 5",
    "receipt_url": "https://storage.example.com/receipts/receipt-123.pdf",
    "payment_method": "Credit Card",
    "is_tax_deductible": true,
    "notes": "Annual curriculum purchase",
    "tags": ["curriculum", "math", "annual"],
    "created_at": "2025-01-15T20:00:00Z",
    "updated_at": "2025-01-15T20:00:00Z"
  }
}
```

---

### 3. Create Expense

Create a new expense.

**Endpoint:** `POST /expenses`

**Authentication:** Required

**Request Body:**
```json
{
  "student_id": "uuid-456",
  "subject_id": "uuid-subject-1",
  "category_id": "uuid-cat-1",
  "expense_date": "2025-01-15",
  "amount": 45.99,
  "vendor": "Amazon",
  "description": "Singapore Math Workbook Level 5",
  "payment_method": "Credit Card",
  "is_tax_deductible": true,
  "notes": "Annual curriculum purchase",
  "tags": ["curriculum", "math", "annual"]
}
```

**Validation Rules:**
- `expense_date`: Required, valid date (YYYY-MM-DD)
- `amount`: Required, positive decimal
- `description`: Required, text
- `student_id`: Optional, null for general expenses
- `subject_id`: Optional, valid subject ID
- `category_id`: Optional, valid category ID
- `vendor`: Optional, max 255 characters
- `currency`: Optional, 3-letter code (default: USD)
- `is_tax_deductible`: Optional, boolean (default: true)
- `tags`: Optional, array of strings

**Success Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-expense-1",
    "teacher_id": "uuid-123",
    "student_id": "uuid-456",
    "expense_date": "2025-01-15",
    "amount": 45.99,
    "description": "Singapore Math Workbook Level 5",
    "created_at": "2025-11-14T16:00:00Z"
  }
}
```

---

### 4. Update Expense

Update an existing expense.

**Endpoint:** `PUT /expenses/{expense_id}`

**Authentication:** Required

**Request Body:**
```json
{
  "amount": 49.99,
  "description": "Singapore Math Workbook Level 5 + Answer Key",
  "notes": "Added answer key to order"
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-expense-1",
    "amount": 49.99,
    "description": "Singapore Math Workbook Level 5 + Answer Key",
    "notes": "Added answer key to order",
    "updated_at": "2025-11-14T16:30:00Z"
  }
}
```

---

### 5. Delete Expense

Delete an expense.

**Endpoint:** `DELETE /expenses/{expense_id}`

**Authentication:** Required

**Success Response (204 No Content)**

---

### 6. Upload Expense Receipt

Upload a receipt image/document for an expense.

**Endpoint:** `POST /expenses/{expense_id}/receipt`

**Authentication:** Required

**Content-Type:** `multipart/form-data`

**Request Body:**
```
file: [file] (PDF, JPEG, PNG, max 10MB)
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "receipt_url": "https://storage.example.com/receipts/receipt-123.pdf",
    "uploaded_at": "2025-11-14T16:00:00Z"
  }
}
```

---

### 7. Get Expense Summary Report

Generate expense summary for a date range with various filters.

**Endpoint:** `GET /expenses/summary`

**Authentication:** Required

**Query Parameters:**
- `student_id` (optional): Filter by student
- `subject_id` (optional): Filter by subject
- `category_id` (optional): Filter by category
- `expense_date_from` (required): Start date
- `expense_date_to` (required): End date
- `group_by` (optional): Group results by (student, subject, category, month)

**Example Request:**
```http
GET /expenses/summary?expense_date_from=2025-01-01&expense_date_to=2025-12-31&group_by=student
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "summary": {
      "total_amount": 2450.75,
      "total_expenses": 47,
      "date_range": {
        "from": "2025-01-01",
        "to": "2025-12-31"
      },
      "grouped_by": "student",
      "groups": [
        {
          "student_id": "uuid-456",
          "student_name": "Emma Johnson",
          "total_amount": 1285.50,
          "expense_count": 25,
          "by_category": [
            {
              "category_name": "Curriculum",
              "total_amount": 675.00,
              "expense_count": 8
            },
            {
              "category_name": "Supplies",
              "total_amount": 410.50,
              "expense_count": 12
            }
          ]
        },
        {
          "student_id": "uuid-789",
          "student_name": "Jack Johnson",
          "total_amount": 865.25,
          "expense_count": 18
        },
        {
          "student_id": null,
          "student_name": "General Expenses",
          "total_amount": 300.00,
          "expense_count": 4
        }
      ]
    }
  }
}
```

---

### 8. Get Expense Categories

Get all expense categories.

**Endpoint:** `GET /expenses/categories`

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid-cat-1",
      "teacher_id": "uuid-123",
      "name": "Curriculum",
      "description": "Textbooks, workbooks, and curriculum materials",
      "color_code": "#4CAF50",
      "icon": "book",
      "is_system_default": true
    },
    {
      "id": "uuid-cat-2",
      "teacher_id": "uuid-123",
      "name": "Field Trips",
      "description": "Educational outings and experiences",
      "color_code": "#2196F3",
      "icon": "bus",
      "is_system_default": true
    }
  ]
}
```

---

### 9. Create Expense Category

Create a custom expense category.

**Endpoint:** `POST /expenses/categories`

**Authentication:** Required

**Request Body:**
```json
{
  "name": "Art Supplies",
  "description": "Paints, brushes, canvas, and art materials",
  "color_code": "#9C27B0",
  "icon": "palette"
}
```

**Success Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-cat-custom-1",
    "teacher_id": "uuid-123",
    "name": "Art Supplies",
    "description": "Paints, brushes, canvas, and art materials",
    "color_code": "#9C27B0",
    "icon": "palette",
    "is_system_default": false
  }
}
```

---

## Subject Endpoints

### 1. Get All Subjects

Get all subjects for authenticated teacher.

**Endpoint:** `GET /subjects`

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid-subject-1",
      "teacher_id": "uuid-123",
      "name": "Mathematics",
      "description": "Arithmetic, algebra, geometry, and problem solving",
      "color_code": "#4CAF50",
      "icon": "calculator",
      "created_at": "2025-01-15T10:00:00Z",
      "updated_at": "2025-01-15T10:00:00Z"
    },
    {
      "id": "uuid-subject-2",
      "teacher_id": "uuid-123",
      "name": "Science",
      "description": "Biology, chemistry, physics, and scientific method",
      "color_code": "#2196F3",
      "icon": "flask",
      "created_at": "2025-01-15T10:00:00Z",
      "updated_at": "2025-01-15T10:00:00Z"
    }
  ]
}
```

---

### 2. Get Single Subject

Get details for a specific subject.

**Endpoint:** `GET /subjects/{subject_id}`

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-subject-1",
    "teacher_id": "uuid-123",
    "name": "Mathematics",
    "description": "Arithmetic, algebra, geometry, and problem solving",
    "color_code": "#4CAF50",
    "icon": "calculator",
    "created_at": "2025-01-15T10:00:00Z",
    "updated_at": "2025-01-15T10:00:00Z"
  }
}
```

---

### 3. Create Subject

Create a new subject.

**Endpoint:** `POST /subjects`

**Authentication:** Required

**Request Body:**
```json
{
  "name": "Mathematics",
  "description": "Arithmetic, algebra, geometry, and problem solving",
  "color_code": "#4CAF50",
  "icon": "calculator"
}
```

**Validation Rules:**
- `name`: Required, max 100 characters
- `description`: Optional, text
- `color_code`: Optional, valid hex color
- `icon`: Optional, max 50 characters

**Success Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-subject-1",
    "teacher_id": "uuid-123",
    "name": "Mathematics",
    "description": "Arithmetic, algebra, geometry, and problem solving",
    "color_code": "#4CAF50",
    "icon": "calculator",
    "created_at": "2025-11-14T16:00:00Z"
  }
}
```

---

### 4. Update Subject

Update an existing subject.

**Endpoint:** `PUT /subjects/{subject_id}`

**Authentication:** Required

**Request Body:**
```json
{
  "name": "Advanced Mathematics",
  "description": "Algebra, geometry, trigonometry, and calculus",
  "color_code": "#1B5E20"
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-subject-1",
    "name": "Advanced Mathematics",
    "description": "Algebra, geometry, trigonometry, and calculus",
    "color_code": "#1B5E20",
    "updated_at": "2025-11-14T16:30:00Z"
  }
}
```

---

### 5. Delete Subject

Delete a subject.

**Endpoint:** `DELETE /subjects/{subject_id}`

**Authentication:** Required

**Success Response (204 No Content)**

**Note:** This will set subject_id to NULL in related records (assignments, expenses, etc.)

---

## Lesson Plan Endpoints

### 1. Get My Lesson Plans

Get lesson plans created by authenticated teacher.

**Endpoint:** `GET /lesson-plans`

**Authentication:** Required

**Query Parameters:**
- `subject_id` (optional): Filter by subject
- `grade_level` (optional): Filter by grade level
- `is_template` (optional): Filter templates only
- `visibility` (optional): Filter by visibility (private, public)
- `sort_by` (optional): Field to sort by (default: created_at)
- `sort_order` (optional): asc or desc (default: desc)
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 20)

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid-lp-1",
      "teacher_id": "uuid-123",
      "subject_id": "uuid-subject-1",
      "subject_name": "Mathematics",
      "title": "Introduction to Fractions",
      "description": "Visual introduction to fraction concepts using pizza slices",
      "grade_level": "3rd-4th Grade",
      "duration_minutes": 45,
      "objectives": "Students will understand fraction notation and identify halves, thirds, and fourths",
      "materials_needed": "Paper plates, markers, scissors",
      "is_template": false,
      "visibility": "private",
      "view_count": 0,
      "created_at": "2025-11-01T10:00:00Z",
      "updated_at": "2025-11-14T15:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 1
  }
}
```

---

### 2. Get Single Lesson Plan

Get details for a specific lesson plan.

**Endpoint:** `GET /lesson-plans/{lesson_plan_id}`

**Authentication:** Required

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-lp-1",
    "teacher_id": "uuid-123",
    "teacher_name": "Sarah Johnson",
    "subject_id": "uuid-subject-1",
    "subject_name": "Mathematics",
    "title": "Introduction to Fractions",
    "description": "Visual introduction to fraction concepts using pizza slices",
    "content": "Full lesson plan content here...",
    "grade_level": "3rd-4th Grade",
    "duration_minutes": 45,
    "objectives": "Students will understand fraction notation and identify halves, thirds, and fourths",
    "materials_needed": "Paper plates, markers, scissors",
    "activities": [
      {
        "name": "Pizza Fraction Activity",
        "duration": 20,
        "description": "Students cut paper plates to create fraction representations"
      }
    ],
    "assessment_methods": "Observe student understanding during activities, check worksheet completion",
    "notes": "Works well with hands-on learners",
    "attachments": [
      {
        "name": "fraction-worksheet.pdf",
        "url": "https://storage.example.com/lesson-plans/worksheet.pdf",
        "type": "pdf"
      }
    ],
    "is_template": false,
    "visibility": "private",
    "view_count": 0,
    "created_at": "2025-11-01T10:00:00Z",
    "updated_at": "2025-11-14T15:00:00Z"
  }
}
```

---

### 3. Create Lesson Plan

Create a new lesson plan.

**Endpoint:** `POST /lesson-plans`

**Authentication:** Required

**Request Body:**
```json
{
  "subject_id": "uuid-subject-1",
  "title": "Introduction to Fractions",
  "description": "Visual introduction to fraction concepts using pizza slices",
  "content": "Full lesson plan content here...",
  "grade_level": "3rd-4th Grade",
  "duration_minutes": 45,
  "objectives": "Students will understand fraction notation and identify halves, thirds, and fourths",
  "materials_needed": "Paper plates, markers, scissors",
  "activities": [
    {
      "name": "Pizza Fraction Activity",
      "duration": 20,
      "description": "Students cut paper plates to create fraction representations"
    }
  ],
  "assessment_methods": "Observe student understanding during activities",
  "notes": "Works well with hands-on learners",
  "is_template": false,
  "visibility": "private"
}
```

**Validation Rules:**
- `title`: Required, max 255 characters
- `subject_id`: Optional, valid subject ID
- `description`: Optional, text
- `content`: Optional, text
- `grade_level`: Optional, max 50 characters
- `duration_minutes`: Optional, positive integer
- `visibility`: Optional, one of: private, public (default: private)

**Success Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-lp-1",
    "teacher_id": "uuid-123",
    "title": "Introduction to Fractions",
    "visibility": "private",
    "created_at": "2025-11-14T16:00:00Z"
  }
}
```

---

### 4. Update Lesson Plan

Update an existing lesson plan.

**Endpoint:** `PUT /lesson-plans/{lesson_plan_id}`

**Authentication:** Required

**Request Body:**
```json
{
  "title": "Introduction to Fractions (Updated)",
  "description": "Enhanced visual introduction to fraction concepts",
  "visibility": "public"
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-lp-1",
    "title": "Introduction to Fractions (Updated)",
    "visibility": "public",
    "updated_at": "2025-11-14T16:30:00Z"
  }
}
```

---

### 5. Delete Lesson Plan

Delete a lesson plan.

**Endpoint:** `DELETE /lesson-plans/{lesson_plan_id}`

**Authentication:** Required

**Success Response (204 No Content)**

---

### 6. Search Public Lesson Plans

Search publicly shared lesson plans from other teachers.

**Endpoint:** `GET /lesson-plans/public`

**Authentication:** Required

**Query Parameters:**
- `search` (optional): Search in title and description
- `subject_id` (optional): Filter by subject
- `grade_level` (optional): Filter by grade level
- `sort_by` (optional): Field to sort by (default: view_count)
- `sort_order` (optional): asc or desc (default: desc)
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 20)

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid-lp-public-1",
      "teacher_id": "uuid-other-teacher",
      "teacher_name": "Jennifer Smith",
      "subject_id": "uuid-subject-1",
      "subject_name": "Mathematics",
      "title": "Fun with Fractions",
      "description": "Engaging fraction lesson using everyday objects",
      "grade_level": "3rd-5th Grade",
      "duration_minutes": 60,
      "view_count": 145,
      "created_at": "2025-10-15T10:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 1
  }
}
```

---

### 7. Copy Public Lesson Plan

Copy a public lesson plan to your own library.

**Endpoint:** `POST /lesson-plans/{lesson_plan_id}/copy`

**Authentication:** Required

**Success Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-lp-copy-1",
    "teacher_id": "uuid-123",
    "title": "Fun with Fractions (Copy)",
    "visibility": "private",
    "created_at": "2025-11-14T16:00:00Z"
  }
}
```

---

### 8. Share Lesson Plan with Specific Teacher

Share a lesson plan privately with another teacher (future feature - V2.0).

**Endpoint:** `POST /lesson-plans/{lesson_plan_id}/share`

**Authentication:** Required

**Request Body:**
```json
{
  "shared_with_teacher_email": "friend@email.com",
  "can_edit": false
}
```

**Success Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "share_id": "uuid-share-1",
    "lesson_plan_id": "uuid-lp-1",
    "shared_with_teacher_email": "friend@email.com",
    "can_edit": false,
    "shared_date": "2025-11-14T16:00:00Z"
  }
}
```

---

### 9. Upload Lesson Plan Attachment

Upload a file attachment to a lesson plan.

**Endpoint:** `POST /lesson-plans/{lesson_plan_id}/attachments`

**Authentication:** Required

**Content-Type:** `multipart/form-data`

**Request Body:**
```
file: [file] (PDF, DOCX, images, max 10MB)
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "attachment": {
      "name": "worksheet.pdf",
      "url": "https://storage.example.com/lesson-plans/worksheet.pdf",
      "type": "pdf",
      "size": 245678,
      "uploaded_at": "2025-11-14T16:00:00Z"
    }
  }
}
```

---

## Appendix

### A. Common Response Examples

#### Successful Creation
```json
{
  "success": true,
  "data": {
    "id": "uuid-123",
    "created_at": "2025-11-14T16:00:00Z"
  }
}
```

#### Validation Error
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": {
      "email": ["Email is required"],
      "password": ["Password must be at least 8 characters"]
    }
  }
}
```

#### Not Found Error
```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "Resource not found"
  }
}
```

#### Unauthorized Error
```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Authentication required"
  }
}
```

---

### B. Date/Time Examples

**ISO 8601 Format:**
```
2025-11-14T15:30:00Z           # UTC time
2025-11-14T15:30:00-05:00      # EST time
2025-11-14                     # Date only
```

---

### C. RRULE Examples for Recurring Events

**Weekly on Mondays, Wednesdays, Fridays:**
```
FREQ=WEEKLY;BYDAY=MO,WE,FR
```

**Daily for 30 occurrences:**
```
FREQ=DAILY;COUNT=30
```

**Monthly on the 15th:**
```
FREQ=MONTHLY;BYMONTHDAY=15
```

**Every other week:**
```
FREQ=WEEKLY;INTERVAL=2
```

---

### D. Grading System Examples

**Letter Grade:**
```json
{
  "letter_grade": "A",
  "percentage_grade": null,
  "standards_rating": null
}
```

**Percentage:**
```json
{
  "letter_grade": null,
  "percentage_grade": 92.5,
  "standards_rating": null
}
```

**Standards-Based:**
```json
{
  "letter_grade": null,
  "percentage_grade": null,
  "standards_rating": "Exceeds Expectations"
}
```

---

### E. JWT Token Payload Example

```json
{
  "sub": "uuid-123",
  "email": "sarah.johnson@email.com",
  "role": "teacher",
  "iat": 1699564800,
  "exp": 1699568400
}
```

**Payload Fields:**
- `sub`: Subject (teacher ID)
- `email`: Teacher email
- `role`: User role (always "teacher" in MVP)
- `iat`: Issued at timestamp
- `exp`: Expiration timestamp

---

### F. File Upload Constraints

| File Type | Max Size | Allowed Extensions |
|-----------|----------|-------------------|
| Profile Images | 5 MB | .jpg, .jpeg, .png, .gif |
| Receipts | 10 MB | .pdf, .jpg, .jpeg, .png |
| Attachments | 10 MB | .pdf, .docx, .doc, .jpg, .jpeg, .png |

---

### G. Security Best Practices

1. **Always use HTTPS** - Never send credentials over HTTP
2. **Store tokens securely** - Use iOS Keychain or Android KeyStore
3. **Implement token refresh** - Don't ask users to log in repeatedly
4. **Validate all inputs** - Never trust client-side data
5. **Hash passwords** - Use bcrypt or argon2 with proper salt
6. **Rate limit authentication** - Prevent brute force attacks
7. **Implement CSRF protection** - For web-based interfaces
8. **Log security events** - Track failed login attempts
9. **Expire sessions** - Force re-authentication after inactivity
10. **Sanitize file uploads** - Validate file types and scan for malware

---

### H. Pagination Example

**Request:**
```http
GET /students?page=2&limit=10
```

**Response:**
```json
{
  "success": true,
  "data": [...],
  "meta": {
    "page": 2,
    "limit": 10,
    "total": 45,
    "total_pages": 5,
    "has_next": true,
    "has_prev": true
  }
}
```

---

## Document Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-14 | Initial API specification document |

---

## Approval & Sign-off

**Prepared by:** API Architecture Team  
**Review Date:** 2025-11-14  
**Status:** Draft - Pending Approval

---

**Next Steps:**
1. Review and approve API specification
2. Set up development environment
3. Implement authentication endpoints first
4. Build core CRUD endpoints
5. Implement file upload functionality
6. Add search and filtering capabilities
7. Implement expense reporting
8. Build lesson plan sharing features
9. Create comprehensive API tests
10. Document deployment procedures
