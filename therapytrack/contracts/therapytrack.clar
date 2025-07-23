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

(define-public (register-therapist
  (therapist-id principal)
  (license-number (string-ascii 50))
  (specialization (string-ascii 100))
  (session-capacity uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR_NOT_AUTHORIZED)
    (map-set therapist-profiles
      { therapist-id: therapist-id }
      {
        license-number: license-number,
        specialization: specialization,
        certification-date: block-height,
        session-capacity: session-capacity,
        current-patients: u0,
        rating-score: u80,
        is-verified: true
      }
    )
    (ok true)
  )
)

(define-public (register-patient
  (patient-id principal)
  (age-group (string-ascii 20))
  (therapy-type (string-ascii 50))
  (assigned-therapist principal))
  (let ((therapist-data (unwrap! (map-get? therapist-profiles { therapist-id: assigned-therapist }) ERR_INVALID_THERAPIST)))
    (asserts! (is-eq tx-sender contract-owner) ERR_NOT_AUTHORIZED)
    (asserts! (get is-verified therapist-data) ERR_INVALID_THERAPIST)
    (map-set patient-records
      { patient-id: patient-id }
      {
        registration-date: block-height,
        age-group: age-group,
        therapy-type: therapy-type,
        assigned-therapist: assigned-therapist,
        session-count: u0,
        last-session: u0,
        is-active: true
      }
    )
    (map-set therapist-profiles
      { therapist-id: assigned-therapist }
      (merge therapist-data { current-patients: (+ (get current-patients therapist-data) u1) })
    )
    (ok true)
  )
)

(define-public (schedule-session
  (patient-id principal)
  (session-date uint)
  (duration-minutes uint)
  (session-type (string-ascii 30)))
  (let ((session-id (var-get next-session-id))
        (patient-data (unwrap! (map-get? patient-records { patient-id: patient-id }) ERR_INVALID_PATIENT))
        (therapist-id (get assigned-therapist patient-data)))
    (asserts! (or (is-eq tx-sender patient-id) (is-eq tx-sender therapist-id)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active patient-data) ERR_INVALID_PATIENT)
    (map-set therapy-sessions
      { session-id: session-id }
      {
        patient-id: patient-id,
        therapist-id: therapist-id,
        session-date: session-date,
        duration-minutes: duration-minutes,
        session-type: session-type,
        notes-hash: 0x00,
        mood-before: u5,
        mood-after: u5,
        homework-assigned: false,
        next-session-scheduled: u0,
        status: "scheduled"
      }
    )
    (var-set next-session-id (+ session-id u1))
    (ok session-id)
  )
)

(define-public (complete-session
  (session-id uint)
  (notes-hash (buff 32))
  (mood-before uint)
  (mood-after uint)
  (homework-assigned bool)
  (next-session-date uint))
  (let ((session-data (unwrap! (map-get? therapy-sessions { session-id: session-id }) ERR_SESSION_NOT_FOUND))
        (patient-id (get patient-id session-data))
        (patient-data (unwrap! (map-get? patient-records { patient-id: patient-id }) ERR_INVALID_PATIENT)))
    (asserts! (is-eq tx-sender (get therapist-id session-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status session-data) "scheduled") ERR_NOT_AUTHORIZED)
    (map-set therapy-sessions
      { session-id: session-id }
      (merge session-data {
        notes-hash: notes-hash,
        mood-before: mood-before,
        mood-after: mood-after,
        homework-assigned: homework-assigned,
        next-session-scheduled: next-session-date,
        status: "completed"
      })
    )
    (map-set patient-records
      { patient-id: patient-id }
      (merge patient-data {
        session-count: (+ (get session-count patient-data) u1),
        last-session: block-height
      })
    )
    (ok true)
  )
)

(define-public (record-session-outcome
  (session-id uint)
  (progress-rating uint)
  (goals-achieved (string-ascii 200))
  (challenges-identified (string-ascii 200))
  (treatment-adjustments (string-ascii 200))
  (follow-up-required bool))
  (let ((session-data (unwrap! (map-get? therapy-sessions { session-id: session-id }) ERR_SESSION_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get therapist-id session-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status session-data) "completed") ERR_NOT_AUTHORIZED)
    (map-set session-outcomes
      { session-id: session-id }
      {
        progress-rating: progress-rating,
        goals-achieved: goals-achieved,
        challenges-identified: challenges-identified,
        treatment-adjustments: treatment-adjustments,
        follow-up-required: follow-up-required
      }
    )
    (ok true)
  )
)

(define-public (create-therapy-goal
  (patient-id principal)
  (goal-description (string-ascii 200))
  (target-date uint))
  (let ((goal-id (var-get next-goal-id))
        (patient-data (unwrap! (map-get? patient-records { patient-id: patient-id }) ERR_INVALID_PATIENT)))
    (asserts! (is-eq tx-sender (get assigned-therapist patient-data)) ERR_NOT_AUTHORIZED)
    (map-set therapy-goals
      { patient-id: patient-id, goal-id: goal-id }
      {
        goal-description: goal-description,
        target-date: target-date,
        progress-percentage: u0,
        status: "active",
        created-by: tx-sender,
        last-updated: block-height
      }
    )
    (var-set next-goal-id (+ goal-id u1))
    (ok goal-id)
  )
)

(define-public (update-goal-progress
  (patient-id principal)
  (goal-id uint)
  (progress-percentage uint))
  (let ((goal-data (unwrap! (map-get? therapy-goals { patient-id: patient-id, goal-id: goal-id }) ERR_SESSION_NOT_FOUND))
        (patient-data (unwrap! (map-get? patient-records { patient-id: patient-id }) ERR_INVALID_PATIENT)))
    (asserts! (is-eq tx-sender (get assigned-therapist patient-data)) ERR_NOT_AUTHORIZED)
    (map-set therapy-goals
      { patient-id: patient-id, goal-id: goal-id }
      (merge goal-data {
        progress-percentage: progress-percentage,
        status: (if (>= progress-percentage u100) "completed" "active"),
        last-updated: block-height
      })
    )
    (ok true)
  )
)

(define-read-only (get-patient-record (patient-id principal))
  (map-get? patient-records { patient-id: patient-id })
)

(define-read-only (get-therapist-profile (therapist-id principal))
  (map-get? therapist-profiles { therapist-id: therapist-id })
)

(define-read-only (get-therapy-session (session-id uint))
  (map-get? therapy-sessions { session-id: session-id })
)

(define-read-only (get-session-outcome (session-id uint))
  (map-get? session-outcomes { session-id: session-id })
)

(define-read-only (get-therapy-goal (patient-id principal) (goal-id uint))
  (map-get? therapy-goals { patient-id: patient-id, goal-id: goal-id })
)

(define-read-only (get-next-session-id)
  (var-get next-session-id)
)

(define-read-only (get-next-goal-id)
  (var-get next-goal-id)
)