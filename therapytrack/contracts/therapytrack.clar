;; TherapyTrack - Mental Health Therapy Session Management
;; Version: 1.0.0

(define-constant ERR_NOT_AUTHORIZED (err u500))
(define-constant ERR_SESSION_NOT_FOUND (err u501))
(define-constant ERR_INVALID_THERAPIST (err u502))
(define-constant ERR_INVALID_PATIENT (err u503))
(define-constant ERR_SESSION_CONFLICT (err u504))

(define-map patient-records
  { patient-id: principal }
  {
    registration-date: uint,
    age-group: (string-ascii 20),
    therapy-type: (string-ascii 50),
    assigned-therapist: principal,
    session-count: uint,
    last-session: uint,
    is-active: bool
  }
)

(define-map therapist-profiles
  { therapist-id: principal }
  {
    license-number: (string-ascii 50),
    specialization: (string-ascii 100),
    certification-date: uint,
    session-capacity: uint,
    current-patients: uint,
    rating-score: uint,
    is-verified: bool
  }
)

(define-map therapy-sessions
  { session-id: uint }
  {
    patient-id: principal,
    therapist-id: principal,
    session-date: uint,
    duration-minutes: uint,
    session-type: (string-ascii 30),
    notes-hash: (buff 32),
    mood-before: uint,
    mood-after: uint,
    homework-assigned: bool,
    next-session-scheduled: uint,
    status: (string-ascii 20)
  }
)

(define-map session-outcomes
  { session-id: uint }
  {
    progress-rating: uint,
    goals-achieved: (string-ascii 200),
    challenges-identified: (string-ascii 200),
    treatment-adjustments: (string-ascii 200),
    follow-up-required: bool
  }
)

(define-map therapy-goals
  { patient-id: principal, goal-id: uint }
  {
    goal-description: (string-ascii 200),
    target-date: uint,
    progress-percentage: uint,
    status: (string-ascii 20),
    created-by: principal,
    last-updated: uint
  }
)

(define-data-var next-session-id uint u1)
(define-data-var next-goal-id uint u1)

(define-constant contract-owner tx-sender)