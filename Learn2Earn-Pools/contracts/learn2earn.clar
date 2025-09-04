 ;; Learn2Earn Pools - Enhanced Study-to-earn rewards system
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-completed (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-invalid-parameters (err u104))
(define-constant err-not-authorized (err u105))
(define-constant err-streak-broken (err u106))
(define-constant err-achievement-exists (err u107))
(define-constant err-quiz-not-passed (err u108))
(define-constant err-cooldown-active (err u109))
(define-constant err-max-attempts-reached (err u110))

;; Data variables
(define-data-var next-module-id uint u0)
(define-data-var next-achievement-id uint u0)
(define-data-var next-quiz-id uint u0)
(define-data-var reward-pool uint u0)
(define-data-var platform-fee-rate uint u250) ;; 2.5% in basis points
(define-data-var min-reward-amount uint u1000000) ;; 1 STX minimum
(define-data-var max-reward-amount uint u100000000) ;; 100 STX maximum
(define-data-var streak-bonus-rate uint u100) ;; 1% bonus per streak day

;; Learning modules with enhanced features
(define-map learning-modules
  { module-id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    category: (string-ascii 50),
    difficulty: uint, ;; 1-5 scale
    reward-amount: uint,
    completions: uint,
    average-rating: uint,
    total-ratings: uint,
    estimated-time: uint, ;; in minutes
    prerequisites: (list 10 uint),
    active: bool,
    created-at: uint
  }
)

;; User completions with enhanced tracking
(define-map user-completions
  { user: principal, module-id: uint }
  { 
    completed-at: uint, 
    reward-claimed: bool,
    completion-time: uint, ;; in minutes
    rating: uint, ;; 1-5 stars
    attempts: uint
  }
)

;; Enhanced user statistics
(define-map user-stats
  { user: principal }
  { 
    total-completed: uint, 
    total-earned: uint,
    current-streak: uint,
    longest-streak: uint,
    last-activity: uint,
    favorite-category: (string-ascii 50),
    skill-level: uint, ;; 1-10 scale
    reputation: uint
  }
)

;; Achievement system
(define-map achievements
  { achievement-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 300),
    reward-amount: uint,
    requirement-type: (string-ascii 50), ;; "streak", "completions", "category", "rating"
    requirement-value: uint,
    icon: (string-ascii 100),
    active: bool
  }
)

;; User achievements
(define-map user-achievements
  { user: principal, achievement-id: uint }
  { unlocked-at: uint, reward-claimed: bool }
)

;; Quiz system for module verification
(define-map module-quizzes
  { quiz-id: uint }
  {
    module-id: uint,
    question-count: uint,
    passing-score: uint, ;; percentage required to pass
    time-limit: uint, ;; in minutes
    active: bool
  }
)

;; Quiz attempts
(define-map quiz-attempts
  { user: principal, quiz-id: uint, attempt: uint }
  {
    score: uint,
    completed-at: uint,
    time-taken: uint,
    passed: bool
  }
)

;; Learning paths - structured course sequences
(define-map learning-paths
  { path-id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    modules: (list 20 uint),
    total-reward: uint,
    difficulty: uint,
    estimated-hours: uint,
    active: bool
  }
)

;; User progress in learning paths
(define-map path-progress
  { user: principal, path-id: uint }
  {
    current-module: uint,
    completed-modules: (list 20 uint),
    started-at: uint,
    last-activity: uint
  }
)

;; Mentorship system
(define-map mentors
  { mentor: principal }
  {
    expertise: (string-ascii 100),
    rating: uint,
    total-students: uint,
    hourly-rate: uint,
    active: bool
  }
)

;; Study groups
(define-map study-groups
  { group-id: uint }
  {
    creator: principal,
    name: (string-ascii 100),
    description: (string-ascii 300),
    category: (string-ascii 50),
    members: (list 50 principal),
    max-members: uint,
    private: bool,
    created-at: uint
  }
)