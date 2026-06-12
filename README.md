# Live preview: [homeschool-master-web.vercel.app](https://homeschool-master-web.vercel.app)

> [!NOTE]
> This is an in-progress build, not the final product. See Status below for what's currently functional.


## Status

This project is currently in active development and not yet launched publicly.

As of 06/12/2026, the working features are user registration, login, logout,
updating your profile name, and changing your password while logged in. The
forgot password reset flow is built, but email delivery is limited for now since I'm
on Resend's free tier, which only delivers to my own verified address, so reset
emails won't reach real users until I verify the domain and move to a paid tier
ahead of launch. Email verification and email change are in the same state for
the same reason.

A few pages are informational only: home, pricing, and contact us. The contact
us page has a form, but it doesn't send email yet. Clicking "Send message"
currently logs the form details to the console instead.

Once logged in, you can view the dashboard with several options to click into.

## Authentication

The API authenticates requests using a JWT stored in the `access_token` cookie.
Every controller that inherits from the API v1 base controller is protected by
this cookie-based check by default. Public endpoints opt out explicitly: login,
register, refresh, and logout, along with the password reset, email
verification, and email change confirmation endpoints.

# Deployment

The Rails API is deployed to Heroku with PostgreSQL via the Heroku Postgres 
add-on. The React web app is deployed to Vercel.

## What's next

- Student management and scheduling
- Lesson planning and curriculum tracking
- React Native mobile app distribution via TestFlight (iOS) and direct APK (Android)


### Documentation can be found here:
[Homescool Master Docs](https://homeschool-master.github.io/homeschool-master-docs/)
