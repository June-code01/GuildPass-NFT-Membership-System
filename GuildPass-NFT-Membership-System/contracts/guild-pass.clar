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