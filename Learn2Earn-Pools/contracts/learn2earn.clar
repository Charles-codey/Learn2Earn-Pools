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

;; Utility function to get maximum of two values
(define-private (max-uint (a uint) (b uint))
  (if (> a b) a b)
)

;; Enhanced pool funding with multi-token support
(define-public (fund-pool (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-parameters)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set reward-pool (+ (var-get reward-pool) amount))
    (ok true)
  )
)

;; Create learning module with enhanced features
(define-public (create-module 
  (title (string-ascii 100)) 
  (description (string-ascii 500))
  (category (string-ascii 50))
  (difficulty uint)
  (reward-amount uint)
  (estimated-time uint)
  (prerequisites (list 10 uint)))
  (let ((module-id (var-get next-module-id)))
    (asserts! (>= (var-get reward-pool) reward-amount) err-insufficient-balance)
    (asserts! (>= reward-amount (var-get min-reward-amount)) err-invalid-parameters)
    (asserts! (<= reward-amount (var-get max-reward-amount)) err-invalid-parameters)
    (asserts! (and (>= difficulty u1) (<= difficulty u5)) err-invalid-parameters)
    
    (map-set learning-modules
      { module-id: module-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        category: category,
        difficulty: difficulty,
        reward-amount: reward-amount,
        completions: u0,
        average-rating: u0,
        total-ratings: u0,
        estimated-time: estimated-time,
        prerequisites: prerequisites,
        active: true,
        created-at: block-height
      }
    )
    (var-set next-module-id (+ module-id u1))
    (ok module-id)
  )
)

;; Complete module with enhanced validation and rewards
(define-public (complete-module (module-id uint) (completion-time uint) (rating uint))
  (let (
    (module (unwrap! (map-get? learning-modules { module-id: module-id }) err-not-found))
    (user tx-sender)
    (user-stats-data (default-to 
      { total-completed: u0, total-earned: u0, current-streak: u0, longest-streak: u0, 
        last-activity: u0, favorite-category: "", skill-level: u1, reputation: u0 }
      (map-get? user-stats { user: user })))
  )
    (asserts! (is-none (map-get? user-completions { user: user, module-id: module-id })) err-already-completed)
    (asserts! (get active module) err-not-found)
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-parameters)
    
    ;; Check prerequisites
    (asserts! (check-prerequisites user (get prerequisites module)) err-not-authorized)
    
    ;; Calculate streak bonus
    (let ((streak-days (calculate-streak user))
          (bonus-amount (/ (* (get reward-amount module) (var-get streak-bonus-rate) streak-days) u10000))
          (total-reward (+ (get reward-amount module) bonus-amount)))
      
      ;; Record completion
      (map-set user-completions
        { user: user, module-id: module-id }
        { 
          completed-at: block-height, 
          reward-claimed: true,
          completion-time: completion-time,
          rating: rating,
          attempts: u1
        }
      )
      
      ;; Update module stats
      (map-set learning-modules
        { module-id: module-id }
        (merge module { 
          completions: (+ (get completions module) u1),
          average-rating: (calculate-new-average (get average-rating module) (get total-ratings module) rating),
          total-ratings: (+ (get total-ratings module) u1)
        })
      )
      
      ;; Transfer rewards
      (try! (as-contract (stx-transfer? total-reward tx-sender user)))
      (var-set reward-pool (- (var-get reward-pool) total-reward))
      
      ;; Update user stats
      (map-set user-stats
        { user: user }
        (merge user-stats-data {
          total-completed: (+ (get total-completed user-stats-data) u1),
          total-earned: (+ (get total-earned user-stats-data) total-reward),
          current-streak: streak-days,
          longest-streak: (update-longest-streak user streak-days),
          last-activity: block-height,
          reputation: (+ (get reputation user-stats-data) (get difficulty module))
        })
      )
      
      ;; Check for achievements
      (try! (check-and-unlock-achievements user))
      (ok total-reward)
    )
  )
)

;; Deactivate module (enhanced with creator check)
(define-public (deactivate-module (module-id uint))
  (let ((module (unwrap! (map-get? learning-modules { module-id: module-id }) err-not-found)))
    (asserts! (or (is-eq tx-sender (get creator module)) (is-eq tx-sender contract-owner)) err-owner-only)
    (map-set learning-modules
      { module-id: module-id }
      (merge module { active: false })
    )
    (ok true)
  )
)

;; Create achievement
(define-public (create-achievement 
  (title (string-ascii 100))
  (description (string-ascii 300))
  (reward-amount uint)
  (requirement-type (string-ascii 50))
  (requirement-value uint)
  (icon (string-ascii 100)))
  (let ((achievement-id (var-get next-achievement-id)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set achievements
      { achievement-id: achievement-id }
      {
        title: title,
        description: description,
        reward-amount: reward-amount,
        requirement-type: requirement-type,
        requirement-value: requirement-value,
        icon: icon,
        active: true
      }
    )
    (var-set next-achievement-id (+ achievement-id u1))
    (ok achievement-id)
  )
)

;; Create quiz for module
(define-public (create-quiz (module-id uint) (question-count uint) (passing-score uint) (time-limit uint))
  (let ((quiz-id (var-get next-quiz-id)))
    (let ((module (unwrap! (map-get? learning-modules { module-id: module-id }) err-not-found)))
      (asserts! (is-eq tx-sender (get creator module)) err-owner-only)
      (asserts! (and (> question-count u0) (<= question-count u50)) err-invalid-parameters)
      (asserts! (and (>= passing-score u50) (<= passing-score u100)) err-invalid-parameters)
      
      (map-set module-quizzes
        { quiz-id: quiz-id }
        {
          module-id: module-id,
          question-count: question-count,
          passing-score: passing-score,
          time-limit: time-limit,
          active: true
        }
      )
      (var-set next-quiz-id (+ quiz-id u1))
      (ok quiz-id)
    )
  )
)

;; Submit quiz attempt
(define-public (submit-quiz (quiz-id uint) (score uint) (time-taken uint))
  (let (
    (quiz (unwrap! (map-get? module-quizzes { quiz-id: quiz-id }) err-not-found))
    (attempt-count (get-user-quiz-attempts tx-sender quiz-id))
  )
    (asserts! (get active quiz) err-not-found)
    (asserts! (< attempt-count u3) err-max-attempts-reached) ;; Max 3 attempts
    (asserts! (and (>= score u0) (<= score u100)) err-invalid-parameters)
    
    (let ((passed (>= score (get passing-score quiz))))
      (map-set quiz-attempts
        { user: tx-sender, quiz-id: quiz-id, attempt: (+ attempt-count u1) }
        {
          score: score,
          completed-at: block-height,
          time-taken: time-taken,
          passed: passed
        }
      )
      (ok passed)
    )
  )
)

;; Unlock achievement for user
(define-public (unlock-achievement (user principal) (achievement-id uint))
  (let ((achievement (unwrap! (map-get? achievements { achievement-id: achievement-id }) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-none (map-get? user-achievements { user: user, achievement-id: achievement-id })) err-achievement-exists)
    
    (map-set user-achievements
      { user: user, achievement-id: achievement-id }
      { unlocked-at: block-height, reward-claimed: false }
    )
    
    ;; Transfer achievement reward
    (try! (as-contract (stx-transfer? (get reward-amount achievement) tx-sender user)))
    (var-set reward-pool (- (var-get reward-pool) (get reward-amount achievement)))
    
    (map-set user-achievements
      { user: user, achievement-id: achievement-id }
      { unlocked-at: block-height, reward-claimed: true }
    )
    
    (ok true)
  )
)

;; Deactivate achievement
(define-public (deactivate-achievement (achievement-id uint))
  (let ((achievement (unwrap! (map-get? achievements { achievement-id: achievement-id }) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set achievements
      { achievement-id: achievement-id }
      (merge achievement { active: false })
    )
    (ok true)
  )
)

;; Deactivate quiz
(define-public (deactivate-quiz (quiz-id uint))
  (let ((quiz (unwrap! (map-get? module-quizzes { quiz-id: quiz-id }) err-not-found)))
    (let ((module (unwrap! (map-get? learning-modules { module-id: (get module-id quiz) }) err-not-found)))
      (asserts! (or (is-eq tx-sender (get creator module)) (is-eq tx-sender contract-owner)) err-owner-only)
      (map-set module-quizzes
        { quiz-id: quiz-id }
        (merge quiz { active: false })
      )
      (ok true)
    )
  )
)

;; Helper functions
(define-private (check-prerequisites (user principal) (prerequisites (list 10 uint)))
  (fold check-single-prerequisite prerequisites true)
)

(define-private (check-single-prerequisite (module-id uint) (acc bool))
  (and acc (is-some (map-get? user-completions { user: tx-sender, module-id: module-id })))
)

(define-private (calculate-streak (user principal))
  (let ((user-data (map-get? user-stats { user: user })))
    (match user-data
      stats (if (< (- block-height (get last-activity stats)) u144) ;; 1 day in blocks
                (+ (get current-streak stats) u1)
                u1)
      u1
    )
  )
)

(define-private (calculate-new-average (current-avg uint) (total-ratings uint) (new-rating uint))
  (if (is-eq total-ratings u0)
      new-rating
      (/ (+ (* current-avg total-ratings) new-rating) (+ total-ratings u1))
  )
)

(define-private (check-and-unlock-achievements (user principal))
  ;; Check completion-based achievements
  (let ((user-data (default-to 
        { total-completed: u0, total-earned: u0, current-streak: u0, longest-streak: u0, 
          last-activity: u0, favorite-category: "", skill-level: u1, reputation: u0 }
        (map-get? user-stats { user: user }))))
    
    ;; Check for "First Module" achievement (achievement-id u0)
    (if (and (is-eq (get total-completed user-data) u1)
             (is-none (map-get? user-achievements { user: user, achievement-id: u0 })))
        (begin
          (map-set user-achievements
            { user: user, achievement-id: u0 }
            { unlocked-at: block-height, reward-claimed: false }
          )
          (ok true)
        )
        (ok true)
    )
  )
)

(define-private (get-user-quiz-attempts (user principal) (quiz-id uint))
  ;; Count existing attempts for user and quiz
  (let ((attempt-1 (map-get? quiz-attempts { user: user, quiz-id: quiz-id, attempt: u1 }))
        (attempt-2 (map-get? quiz-attempts { user: user, quiz-id: quiz-id, attempt: u2 }))
        (attempt-3 (map-get? quiz-attempts { user: user, quiz-id: quiz-id, attempt: u3 })))
    (+ (if (is-some attempt-1) u1 u0)
       (+ (if (is-some attempt-2) u1 u0) 
          (if (is-some attempt-3) u1 u0)))
  )
)

(define-private (calculate-user-reputation (user principal) (difficulty uint))
  (let ((current-stats (default-to 
        { total-completed: u0, total-earned: u0, current-streak: u0, longest-streak: u0, 
          last-activity: u0, favorite-category: "", skill-level: u1, reputation: u0 }
        (map-get? user-stats { user: user }))))
    (+ (get reputation current-stats) (* difficulty u10))
  )
)

(define-private (update-longest-streak (user principal) (current-streak uint))
  (let ((user-data (map-get? user-stats { user: user })))
    (match user-data
      stats (max-uint current-streak (get longest-streak stats))
      current-streak
    )
  )
)

(define-private (is-module-prerequisite-met (user principal) (module-id uint))
  (is-some (map-get? user-completions { user: user, module-id: module-id }))
)

(define-private (calculate-skill-level (reputation uint))
  (cond 
    ((< reputation u100) u1)
    ((< reputation u500) u2)
    ((< reputation u1000) u3)
    ((< reputation u2000) u4)
    ((< reputation u5000) u5)
    ((< reputation u10000) u6)
    ((< reputation u20000) u7)
    ((< reputation u50000) u8)
    ((< reputation u100000) u9)
    (true u10)
  )
)

(define-private (get-category-completion-count (user principal) (category (string-ascii 50)))
  ;; This would require iterating through user completions
  ;; Simplified implementation for now
  u0
)

(define-private (validate-module-parameters 
  (title (string-ascii 100))
  (reward-amount uint)
  (difficulty uint)
  (estimated-time uint))
  (and 
    (> (len title) u0)
    (and (>= difficulty u1) (<= difficulty u5))
    (and (>= reward-amount (var-get min-reward-amount)) 
         (<= reward-amount (var-get max-reward-amount)))
    (> estimated-time u0)
  )
)

;; Administrative functions
(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u1000) err-invalid-parameters) ;; Max 10%
    (var-set platform-fee-rate new-fee)
    (ok true)
  )
)

(define-public (set-reward-limits (min-reward uint) (max-reward uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (< min-reward max-reward) err-invalid-parameters)
    (var-set min-reward-amount min-reward)
    (var-set max-reward-amount max-reward)
    (ok true)
  )
)

(define-public (set-streak-bonus-rate (bonus-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= bonus-rate u500) err-invalid-parameters) ;; Max 5% bonus per day
    (var-set streak-bonus-rate bonus-rate)
    (ok true)
  )
)

(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= amount (var-get reward-pool)) err-insufficient-balance)
    (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
    (var-set reward-pool (- (var-get reward-pool) amount))
    (ok true)
  )
)

(define-public (register-mentor 
  (expertise (string-ascii 100))
  (hourly-rate uint))
  (begin
    (asserts! (> (len expertise) u0) err-invalid-parameters)
    (asserts! (> hourly-rate u0) err-invalid-parameters)
    (map-set mentors
      { mentor: tx-sender }
      {
        expertise: expertise,
        rating: u5, ;; Default 5/10 rating
        total-students: u0,
        hourly-rate: hourly-rate,
        active: true
      }
    )
    (ok true)
  )
)

(define-public (update-mentor-rating (mentor principal) (new-rating uint))
  (let ((mentor-data (unwrap! (map-get? mentors { mentor: mentor }) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (and (>= new-rating u1) (<= new-rating u10)) err-invalid-parameters)
    (map-set mentors
      { mentor: mentor }
      (merge mentor-data { rating: new-rating })
    )
    (ok true)
  )
)

(define-public (deactivate-mentor (mentor principal))
  (let ((mentor-data (unwrap! (map-get? mentors { mentor: mentor }) err-not-found)))
    (asserts! (or (is-eq tx-sender mentor) (is-eq tx-sender contract-owner)) err-owner-only)
    (map-set mentors
      { mentor: mentor }
      (merge mentor-data { active: false })
    )
    (ok true)
  )
)

(define-public (create-study-group 
  (name (string-ascii 100))
  (description (string-ascii 300))
  (category (string-ascii 50))
  (max-members uint)
  (private bool))
  (let ((group-id (var-get next-quiz-id))) ;; Reusing counter for simplicity
    (asserts! (> (len name) u0) err-invalid-parameters)
    (asserts! (and (> max-members u1) (<= max-members u50)) err-invalid-parameters)
    (map-set study-groups
      { group-id: group-id }
      {
        creator: tx-sender,
        name: name,
        description: description,
        category: category,
        members: (list tx-sender),
        max-members: max-members,
        private: private,
        created-at: block-height
      }
    )
    (var-set next-quiz-id (+ group-id u1))
    (ok group-id)
  )
)

(define-public (join-study-group (group-id uint))
  (let ((group (unwrap! (map-get? study-groups { group-id: group-id }) err-not-found)))
    (asserts! (< (len (get members group)) (get max-members group)) err-invalid-parameters)
    (asserts! (is-none (index-of (get members group) tx-sender)) err-already-completed) ;; Already member
    (map-set study-groups
      { group-id: group-id }
      (merge group { 
        members: (unwrap! (as-max-len? (append (get members group) tx-sender) u50) err-invalid-parameters)
      })
    )
    (ok true)
  )
)

(define-public (leave-study-group (group-id uint))
  (let ((group (unwrap! (map-get? study-groups { group-id: group-id }) err-not-found)))
    (asserts! (is-some (index-of (get members group) tx-sender)) err-not-found) ;; Not a member
    (asserts! (not (is-eq tx-sender (get creator group))) err-owner-only) ;; Creator cannot leave
    (map-set study-groups
      { group-id: group-id }
      (merge group { 
        members: (filter remove-member-filter (get members group))
      })
    )
    (ok true)
  )
)

(define-private (remove-member-filter (member principal))
  (not (is-eq member tx-sender))
)

;; Read-only functions for data access
(define-read-only (get-module (module-id uint))
  (map-get? learning-modules { module-id: module-id })
)

(define-read-only (get-user-completion (user principal) (module-id uint))
  (map-get? user-completions { user: user, module-id: module-id })
)

(define-read-only (get-user-stats (user principal))
  (map-get? user-stats { user: user })
)

(define-read-only (get-reward-pool)
  (var-get reward-pool)
)

(define-read-only (get-achievement (achievement-id uint))
  (map-get? achievements { achievement-id: achievement-id })
)

(define-read-only (get-user-achievement (user principal) (achievement-id uint))
  (map-get? user-achievements { user: user, achievement-id: achievement-id })
)

(define-read-only (get-quiz (quiz-id uint))
  (map-get? module-quizzes { quiz-id: quiz-id })
)

(define-read-only (get-quiz-attempt (user principal) (quiz-id uint) (attempt uint))
  (map-get? quiz-attempts { user: user, quiz-id: quiz-id, attempt: attempt })
)

(define-read-only (get-learning-path (path-id uint))
  (map-get? learning-paths { path-id: path-id })
)

(define-read-only (get-path-progress (user principal) (path-id uint))
  (map-get? path-progress { user: user, path-id: path-id })
)

(define-read-only (get-mentor (mentor principal))
  (map-get? mentors { mentor: mentor })
)

(define-read-only (get-study-group (group-id uint))
  (map-get? study-groups { group-id: group-id })
)

(define-read-only (get-contract-info)
  {
    total-modules: (var-get next-module-id),
    total-achievements: (var-get next-achievement-id),
    total-quizzes: (var-get next-quiz-id),
    reward-pool: (var-get reward-pool),
    platform-fee: (var-get platform-fee-rate),
    min-reward: (var-get min-reward-amount),
    max-reward: (var-get max-reward-amount),
    streak-bonus: (var-get streak-bonus-rate),
    owner: contract-owner
  }
)

(define-read-only (get-platform-stats)
  {
    total-modules: (var-get next-module-id),
    reward-pool: (var-get reward-pool),
    active-achievements: (var-get next-achievement-id),
    total-quizzes: (var-get next-quiz-id)
  }
)

(define-read-only (get-user-profile (user principal))
  (let ((stats (get-user-stats user)))
    (match stats
      user-data {
        user: user,
        stats: user-data,
        skill-level: (calculate-skill-level (get reputation user-data)),
        is-mentor: (is-some (get-mentor user))
      }
      {
        user: user,
        stats: none,
        skill-level: u1,
        is-mentor: false
      }
    )
  )
)

(define-read-only (get-module-analytics (module-id uint))
  (let ((module (get-module module-id)))
    (match module
      module-data {
        module-id: module-id,
        completions: (get completions module-data),
        average-rating: (get average-rating module-data),
        total-ratings: (get total-ratings module-data),
        success-rate: (if (> (get completions module-data) u0) 
                        (/ (* (get completions module-data) u100) (get completions module-data)) 
                        u0),
        popularity-score: (+ (get completions module-data) (get total-ratings module-data))
      }
      none
    )
  )
)

(define-read-only (get-user-achievements-count (user principal))
  ;; This would require iterating through all achievements in a real implementation
  ;; Simplified version that checks first 10 achievement IDs
  (let ((achievement-0 (get-user-achievement user u0))
        (achievement-1 (get-user-achievement user u1))
        (achievement-2 (get-user-achievement user u2))
        (achievement-3 (get-user-achievement user u3))
        (achievement-4 (get-user-achievement user u4)))
    (+ (if (is-some achievement-0) u1 u0)
       (+ (if (is-some achievement-1) u1 u0)
          (+ (if (is-some achievement-2) u1 u0)
             (+ (if (is-some achievement-3) u1 u0)
                (if (is-some achievement-4) u1 u0)))))
  )
)

(define-read-only (check-module-eligibility (user principal) (module-id uint))
  (let ((module (get-module module-id)))
    (match module
      module-data {
        eligible: (and (get active module-data) 
                       (check-prerequisites user (get prerequisites module-data))),
        prerequisites-met: (check-prerequisites user (get prerequisites module-data)),
        already-completed: (is-some (get-user-completion user module-id))
      }
      {
        eligible: false,
        prerequisites-met: false,
        already-completed: false
      }
    )
  )
)

(define-read-only (get-user-quiz-summary (user principal) (quiz-id uint))
  (let ((attempt-1 (get-quiz-attempt user quiz-id u1))
        (attempt-2 (get-quiz-attempt user quiz-id u2))
        (attempt-3 (get-quiz-attempt user quiz-id u3)))
    {
      total-attempts: (get-user-quiz-attempts user quiz-id),
      best-score: (get-best-quiz-score user quiz-id),
      passed: (or (match attempt-1 a1 (get passed a1) false)
                  (or (match attempt-2 a2 (get passed a2) false)
                      (match attempt-3 a3 (get passed a3) false))),
      attempts-remaining: (- u3 (get-user-quiz-attempts user quiz-id))
    }
  )
)

(define-read-only (get-best-quiz-score (user principal) (quiz-id uint))
  (let ((attempt-1 (get-quiz-attempt user quiz-id u1))
        (attempt-2 (get-quiz-attempt user quiz-id u2))
        (attempt-3 (get-quiz-attempt user quiz-id u3)))
    (let ((score-1 (match attempt-1 a1 (get score a1) u0))
          (score-2 (match attempt-2 a2 (get score a2) u0))
          (score-3 (match attempt-3 a3 (get score a3) u0)))
      (max-uint score-1 (max-uint score-2 score-3))
    )
  )
)

(define-read-only (get-modules-by-category (category (string-ascii 50)))
  ;; This would require filtering in a real implementation
  ;; Returning a simplified structure for demonstration
  {
    category: category,
    total-modules: u0, ;; Would be calculated by iterating through modules
    average-difficulty: u3, ;; Would be calculated from actual modules
    total-completions: u0 ;; Would be summed from all modules in category
  }
)

(define-read-only (is-user-mentor (user principal))
  (is-some (get-mentor user))
)

(define-read-only (get-learning-streak-info (user principal))
  (let ((stats (get-user-stats user)))
    (match stats
      user-data {
        current-streak: (get current-streak user-data),
        longest-streak: (get longest-streak user-data),
        days-since-activity: (if (> (get last-activity user-data) u0)
                                (- block-height (get last-activity user-data))
                                u0),
        next-streak-bonus: (* (+ (get current-streak user-data) u1) (var-get streak-bonus-rate))
      }
      {
        current-streak: u0,
        longest-streak: u0,
        days-since-activity: u0,
        next-streak-bonus: (var-get streak-bonus-rate)
      }
    )
  )
)