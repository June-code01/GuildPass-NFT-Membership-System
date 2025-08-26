;; GuildPass - NFT-based Gaming Guild Membership System
;; Provides exclusive access to guild features through NFT ownership

(define-non-fungible-token guild-pass uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-member (err u101))
(define-constant err-guild-not-found (err u102))
(define-constant err-access-denied (err u103))
(define-constant err-already-member (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-tournament-full (err u106))
(define-constant err-tournament-not-found (err u107))
(define-constant err-invalid-parameters (err u108))
(define-constant err-transfer-failed (err u109))
(define-constant err-not-guild-leader (err u110))

(define-data-var next-pass-id uint u1)
(define-data-var next-guild-id uint u1)
(define-data-var next-tournament-id uint u1)
(define-data-var guild-treasury uint u0)
(define-data-var platform-fee-rate uint u5) ;; 5% platform fee

(define-map guild-passes
  { pass-id: uint }
  {
    guild-id: uint,
    member-name: (string-ascii 50),
    pass-type: (string-ascii 20),
    issue-date: uint,
    access-level: uint,
    is-active: bool,
    experience-points: uint,
    achievements: (list 10 (string-ascii 30))
  })

(define-map gaming-guilds
  { guild-id: uint }
  {
    guild-name: (string-ascii 50),
    guild-leader: principal,
    max-members: uint,
    current-members: uint,
    guild-type: (string-ascii 30),
    entry-requirements: (string-ascii 100),
    created-date: uint,
    guild-treasury: uint,
    reputation-score: uint,
    is-recruiting: bool
  })

(define-map member-access
  { member: principal, guild-id: uint }
  { pass-id: uint, access-granted: bool, join-date: uint, last-activity: uint })

(define-map access-levels
  { level: uint }
  { 
    level-name: (string-ascii 30),
    tournament-access: bool,
    server-access: bool,
    loot-bonus: uint,
    voting-power: uint
  })

(define-map tournaments
  { tournament-id: uint }
  {
    tournament-name: (string-ascii 50),
    guild-id: uint,
    entry-fee: uint,
    prize-pool: uint,
    max-participants: uint,
    current-participants: uint,
    start-date: uint,
    end-date: uint,
    min-access-level: uint,
    is-active: bool
  })

(define-map tournament-participants
  { tournament-id: uint, participant: principal }
  { joined-date: uint, entry-paid: bool })

(define-map guild-votes
  { guild-id: uint, proposal-id: uint }
  {
    proposal-title: (string-ascii 100),
    description: (string-ascii 200),
    votes-for: uint,
    votes-against: uint,
    voting-deadline: uint,
    is-active: bool,
    created-by: principal
  })

(define-map member-votes
  { guild-id: uint, proposal-id: uint, voter: principal }
  { vote: bool, voting-power: uint })

;; Initialize access levels
(map-set access-levels { level: u1 } 
  { level-name: "bronze", tournament-access: false, server-access: true, loot-bonus: u5, voting-power: u1 })
(map-set access-levels { level: u2 } 
  { level-name: "silver", tournament-access: true, server-access: true, loot-bonus: u10, voting-power: u2 })
(map-set access-levels { level: u3 } 
  { level-name: "gold", tournament-access: true, server-access: true, loot-bonus: u20, voting-power: u3 })
(map-set access-levels { level: u4 } 
  { level-name: "platinum", tournament-access: true, server-access: true, loot-bonus: u30, voting-power: u5 })
(map-set access-levels { level: u5 } 
  { level-name: "diamond", tournament-access: true, server-access: true, loot-bonus: u50, voting-power: u8 })

(define-public (create-guild
  (guild-name (string-ascii 50))
  (max-members uint)
  (guild-type (string-ascii 30))
  (entry-requirements (string-ascii 100)))
  (let 
    ((guild-id (var-get next-guild-id))
     (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1)))))
    (begin
      (asserts! (> max-members u0) err-invalid-parameters)
      (map-set gaming-guilds { guild-id: guild-id }
        {
          guild-name: guild-name,
          guild-leader: tx-sender,
          max-members: max-members,
          current-members: u0,
          guild-type: guild-type,
          entry-requirements: entry-requirements,
          created-date: current-time,
          guild-treasury: u0,
          reputation-score: u100,
          is-recruiting: true
        })
      (var-set next-guild-id (+ guild-id u1))
      (ok guild-id))))

(define-public (toggle-guild-recruiting (guild-id uint))
  (let ((guild-info (unwrap! (map-get? gaming-guilds { guild-id: guild-id }) err-guild-not-found)))
    (begin
      (asserts! (is-eq tx-sender (get guild-leader guild-info)) err-not-guild-leader)
      (map-set gaming-guilds { guild-id: guild-id }
        (merge guild-info { is-recruiting: (not (get is-recruiting guild-info)) }))
      (ok true))))

(define-public (transfer-guild-leadership (guild-id uint) (new-leader principal))
  (let ((guild-info (unwrap! (map-get? gaming-guilds { guild-id: guild-id }) err-guild-not-found)))
    (begin
      (asserts! (is-eq tx-sender (get guild-leader guild-info)) err-not-guild-leader)
      (asserts! (is-some (map-get? member-access { member: new-leader, guild-id: guild-id })) err-not-member)
      (map-set gaming-guilds { guild-id: guild-id }
        (merge guild-info { guild-leader: new-leader }))
      (ok true))))

(define-public (mint-guild-pass
  (recipient principal)
  (guild-id uint)
  (member-name (string-ascii 50))
  (pass-type (string-ascii 20))
  (access-level uint))
  (let 
    ((pass-id (var-get next-pass-id))
     (guild-info (unwrap! (map-get? gaming-guilds { guild-id: guild-id }) err-guild-not-found))
     (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1)))))
    (begin
      (asserts! (is-eq tx-sender (get guild-leader guild-info)) err-not-guild-leader)
      (asserts! (is-none (map-get? member-access { member: recipient, guild-id: guild-id })) err-already-member)
      (asserts! (< (get current-members guild-info) (get max-members guild-info)) err-access-denied)
      (asserts! (get is-recruiting guild-info) err-access-denied)
      (asserts! (<= access-level u5) err-invalid-parameters)
      
      (try! (nft-mint? guild-pass pass-id recipient))
      
      (map-set guild-passes { pass-id: pass-id }
        {
          guild-id: guild-id,
          member-name: member-name,
          pass-type: pass-type,
          issue-date: current-time,
          access-level: access-level,
          is-active: true,
          experience-points: u0,
          achievements: (list)
        })
      
      (map-set member-access { member: recipient, guild-id: guild-id }
        { pass-id: pass-id, access-granted: true, join-date: current-time, last-activity: current-time })
      
      (map-set gaming-guilds { guild-id: guild-id }
        (merge guild-info { current-members: (+ (get current-members guild-info) u1) }))
      
      (var-set next-pass-id (+ pass-id u1))
      (ok pass-id))))

(define-public (upgrade-access-level (pass-id uint) (new-level uint))
  (let ((pass-info (unwrap! (map-get? guild-passes { pass-id: pass-id }) err-not-member))
        (guild-info (unwrap! (map-get? gaming-guilds { guild-id: (get guild-id pass-info) }) err-guild-not-found)))
    (begin
      (asserts! (is-eq tx-sender (get guild-leader guild-info)) err-not-guild-leader)
      (asserts! (> new-level (get access-level pass-info)) err-invalid-parameters)
      (asserts! (<= new-level u5) err-invalid-parameters)
      (map-set guild-passes { pass-id: pass-id }
        (merge pass-info { access-level: new-level }))
      (ok true))))

(define-public (add-experience-points (pass-id uint) (points uint))
  (let ((pass-info (unwrap! (map-get? guild-passes { pass-id: pass-id }) err-not-member))
        (guild-info (unwrap! (map-get? gaming-guilds { guild-id: (get guild-id pass-info) }) err-guild-not-found)))
    (begin
      (asserts! (is-eq tx-sender (get guild-leader guild-info)) err-not-guild-leader)
      (map-set guild-passes { pass-id: pass-id }
        (merge pass-info { experience-points: (+ (get experience-points pass-info) points) }))
      (ok true))))

(define-public (update-member-activity (guild-id uint))
  (let 
    ((member-info (unwrap! (map-get? member-access { member: tx-sender, guild-id: guild-id }) err-not-member))
     (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1)))))
    (begin
      (map-set member-access { member: tx-sender, guild-id: guild-id }
        (merge member-info { last-activity: current-time }))
      (ok true))))

(define-public (leave-guild (guild-id uint))
  (let 
    ((member-info (unwrap! (map-get? member-access { member: tx-sender, guild-id: guild-id }) err-not-member))
     (guild-info (unwrap! (map-get? gaming-guilds { guild-id: guild-id }) err-guild-not-found))
     (pass-info (unwrap! (map-get? guild-passes { pass-id: (get pass-id member-info) }) err-not-member)))
    (begin
      (asserts! (not (is-eq tx-sender (get guild-leader guild-info))) err-access-denied)
      
      (map-delete member-access { member: tx-sender, guild-id: guild-id })
      (map-set guild-passes { pass-id: (get pass-id member-info) }
        (merge pass-info { is-active: false }))
      (map-set gaming-guilds { guild-id: guild-id }
        (merge guild-info { current-members: (- (get current-members guild-info) u1) }))
      
      (ok true))))

(define-public (create-tournament
  (tournament-name (string-ascii 50))
  (guild-id uint)
  (entry-fee uint)
  (max-participants uint)
  (start-date uint)
  (end-date uint)
  (min-access-level uint))
  (let 
    ((tournament-id (var-get next-tournament-id))
     (guild-info (unwrap! (map-get? gaming-guilds { guild-id: guild-id }) err-guild-not-found)))
    (begin
      (asserts! (is-eq tx-sender (get guild-leader guild-info)) err-not-guild-leader)
      (asserts! (> max-participants u0) err-invalid-parameters)
      (asserts! (> end-date start-date) err-invalid-parameters)
      (asserts! (<= min-access-level u5) err-invalid-parameters)
      
      (map-set tournaments { tournament-id: tournament-id }
        {
          tournament-name: tournament-name,
          guild-id: guild-id,
          entry-fee: entry-fee,
          prize-pool: u0,
          max-participants: max-participants,
          current-participants: u0,
          start-date: start-date,
          end-date: end-date,
          min-access-level: min-access-level,
          is-active: true
        })
      
      (var-set next-tournament-id (+ tournament-id u1))
      (ok tournament-id))))

(define-public (join-tournament (tournament-id uint))
  (let 
    ((tournament-info (unwrap! (map-get? tournaments { tournament-id: tournament-id }) err-tournament-not-found))
     (member-info (unwrap! (map-get? member-access { member: tx-sender, guild-id: (get guild-id tournament-info) }) err-not-member))
     (pass-info (unwrap! (map-get? guild-passes { pass-id: (get pass-id member-info) }) err-not-member))
     (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1)))))
    (begin
      (asserts! (get is-active tournament-info) err-access-denied)
      (asserts! (< (get current-participants tournament-info) (get max-participants tournament-info)) err-tournament-full)
      (asserts! (>= (get access-level pass-info) (get min-access-level tournament-info)) err-access-denied)
      (asserts! (< current-time (get start-date tournament-info)) err-access-denied)
      
      (if (> (get entry-fee tournament-info) u0)
        (try! (stx-transfer? (get entry-fee tournament-info) tx-sender (as-contract tx-sender)))
        true)
      
      (map-set tournament-participants { tournament-id: tournament-id, participant: tx-sender }
        { joined-date: current-time, entry-paid: true })
      
      (map-set tournaments { tournament-id: tournament-id }
        (merge tournament-info { 
          current-participants: (+ (get current-participants tournament-info) u1),
          prize-pool: (+ (get prize-pool tournament-info) (get entry-fee tournament-info))
        }))
      
      (ok true))))