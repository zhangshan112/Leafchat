import Foundation

// MARK: - Community member

/// Curated community gardener profile for mock feed authors and commenters.
struct CommunityMemberProfile: Identifiable, Hashable {
    let id: String
    let username: String
    let bio: String
    let country: String
    let plantsCount: Int
    let followersCount: Int
    let followingCount: Int

    var postCardUser: PostCardUser {
        PostCardUser(
            id: id,
            username: username,
            avatarUrlString: CommunityAvatarAssets.avatarUrlString(forUserId: id)
        )
    }
}

// MARK: - Post comment thread

struct PostCommentThread: Identifiable {
    let id: String
    let comment: CommentCardData
    let replies: [CommentCardData]
}

// MARK: - Garden community profiles

enum GardenCommunityProfiles {

    static let members: [CommunityMemberProfile] = [
        .init(
            id: "u1",
            username: "fernqueen",
            bio: "Boston fern mom · misting evangelist · humidity above 55% or we riot",
            country: "Netherlands",
            plantsCount: 14,
            followersCount: 1_840,
            followingCount: 312
        ),
        .init(
            id: "u2",
            username: "cactus_crew",
            bio: "Desert succulents on a sunny patio · gritty mix only · no sympathy for soggy soil",
            country: "Arizona, USA",
            plantsCount: 22,
            followersCount: 2_410,
            followingCount: 198
        ),
        .init(
            id: "u3",
            username: "leafy_life",
            bio: "Pothos in every corner · documenting yellow-leaf mysteries · Manchester flat jungle",
            country: "United Kingdom",
            plantsCount: 11,
            followersCount: 976,
            followingCount: 445
        ),
        .init(
            id: "u4",
            username: "roots_n_grows",
            bio: "Propagation lab on the kitchen counter · water-rooting enthusiast · Berlin",
            country: "Germany",
            plantsCount: 18,
            followersCount: 1_520,
            followingCount: 267
        ),
        .init(
            id: "u5",
            username: "jungle_studio",
            bio: "Tropical balcony in the tropics · morning sun, afternoon shade · fern fences",
            country: "Singapore",
            plantsCount: 16,
            followersCount: 2_090,
            followingCount: 388
        ),
        .init(
            id: "u6",
            username: "aroid_archive",
            bio: "Monstera & Alocasia collector · unfurl watch every spring · Toronto apartment grower",
            country: "Canada",
            plantsCount: 9,
            followersCount: 1_260,
            followingCount: 201
        ),
        .init(
            id: "u7",
            username: "humidity_hero",
            bio: "Calathea whisperer · pebble trays & hygrometers · Florida heat survivor",
            country: "United States",
            plantsCount: 13,
            followersCount: 1_680,
            followingCount: 354
        ),
        .init(
            id: "u8",
            username: "sunlit_shelf",
            bio: "Herb balcony chef · basil pinches & rosemary roasts · Barcelona south exposure",
            country: "Spain",
            plantsCount: 8,
            followersCount: 890,
            followingCount: 156
        ),
        .init(
            id: "u9",
            username: "desk_garden",
            bio: "Tiny succulents that survive office AC · haworthia desk squad · Tokyo commuter",
            country: "Japan",
            plantsCount: 7,
            followersCount: 640,
            followingCount: 122
        ),
        .init(
            id: "u10",
            username: "variegation_vibes",
            bio: "Chasing white splashes on pothos & philodendron · east-window experiments",
            country: "Australia",
            plantsCount: 12,
            followersCount: 1_430,
            followingCount: 289
        ),
        .init(
            id: "u11",
            username: "propagation_station",
            bio: "Neighborhood plant swaps · spider-plant pup factory · Dublin porch grower",
            country: "Ireland",
            plantsCount: 15,
            followersCount: 1_110,
            followingCount: 402
        ),
        .init(
            id: "u12",
            username: "mosspole_maven",
            bio: "Moss poles & aerial roots · climbing aroids only · Stockholm loft light",
            country: "Sweden",
            plantsCount: 10,
            followersCount: 1_350,
            followingCount: 178
        ),
        .init(
            id: "u13",
            username: "root_check",
            bio: "Fiddle-leaf fig ER · repot rescue stories · Austin plant triage",
            country: "United States",
            plantsCount: 6,
            followersCount: 2_020,
            followingCount: 145
        ),
        .init(
            id: "u14",
            username: "water_watcher",
            bio: "Soil moisture routines · peace-lily wilt detective · Lyon apartment grower",
            country: "France",
            plantsCount: 9,
            followersCount: 720,
            followingCount: 233
        ),
        .init(
            id: "u15",
            username: "sun_seeker",
            bio: "Chasing brighter windows · fixing etiolated succulents · SF fog fighter",
            country: "United States",
            plantsCount: 17,
            followersCount: 1_890,
            followingCount: 301
        ),
        .init(
            id: "u16",
            username: "rail_planter",
            bio: "Railing containers & heat-wave soaks · geranium color pops · Rome balcony",
            country: "Italy",
            plantsCount: 11,
            followersCount: 1_040,
            followingCount: 219
        ),
    ]

    private static let membersByID: [String: CommunityMemberProfile] = {
        Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
    }()

    static func member(id: String) -> CommunityMemberProfile? {
        membersByID[id]
    }

    static func postCardUser(id: String) -> PostCardUser {
        member(id: id)?.postCardUser ?? PostCardUser(id: id, username: "User", avatarUrlString: nil)
    }

    static func profileHeader(
        userId: String,
        postsCount: Int,
        isFollowing: Bool
    ) -> ProfileHeaderData {
        let profile = member(id: userId)
        return ProfileHeaderData(
            id: userId,
            username: profile?.username ?? "User",
            avatarUrlString: CommunityAvatarAssets.avatarUrlString(forUserId: userId),
            bio: profile?.bio ?? "",
            country: profile?.country ?? "",
            postsCount: postsCount,
            plantsCount: profile?.plantsCount ?? 0,
            followersCount: profile?.followersCount ?? 0,
            followingCount: profile?.followingCount ?? 0,
            isFollowing: isFollowing
        )
    }

    static func userCardData(id: String) -> UserCardData? {
        guard let profile = member(id: id) else { return nil }
        return UserCardData(
            id: profile.id,
            username: profile.username,
            avatarURL: CommunityAvatarAssets.avatarURL(forUserId: profile.id),
            bio: profile.bio,
            isFollowing: false
        )
    }

    static func commentThreads(for postId: String) -> [PostCommentThread] {
        commentsByPostId[postId] ?? []
    }

    // MARK: - Comment builders

    private static func comment(
        id: String,
        memberId: String,
        content: String,
        createdAtOffset: TimeInterval,
        likeCount: Int = 0,
        isLiked: Bool = false
    ) -> CommentCardData {
        let profile = member(id: memberId)!
        return CommentCardData(
            id: id,
            userId: profile.id,
            username: profile.username,
            avatarURL: CommunityAvatarAssets.avatarURL(forUserId: memberId),
            content: content,
            createdAt: Date().addingTimeInterval(createdAtOffset),
            likeCount: likeCount,
            isLiked: isLiked
        )
    }

    private static let commentsByPostId: [String: [PostCommentThread]] = [
        "er1": [
            PostCommentThread(
                id: "er1-c1",
                comment: comment(
                    id: "er1-c1",
                    memberId: "u7",
                    content: "AC vents are brutal — glad you caught the draft early.",
                    createdAtOffset: -2_400,
                    likeCount: 5
                ),
                replies: [
                    comment(
                        id: "er1-r1",
                        memberId: "u3",
                        content: "Day 3 and no new yellowing — fingers crossed!",
                        createdAtOffset: -1_800,
                        likeCount: 2
                    )
                ]
            ),
            PostCommentThread(
                id: "er1-c2",
                comment: comment(
                    id: "er1-c2",
                    memberId: "u14",
                    content: "Top-inch dry before watering again — that rule saved my pothos too.",
                    createdAtOffset: -1_200,
                    likeCount: 3,
                    isLiked: true
                ),
                replies: []
            ),
        ],
        "er2": [
            PostCommentThread(
                id: "er2-c1",
                comment: comment(
                    id: "er2-c1",
                    memberId: "u1",
                    content: "Grouping with ferns is smart. My orbifolia loves the shared humidity.",
                    createdAtOffset: -3_000,
                    likeCount: 6
                ),
                replies: []
            ),
            PostCommentThread(
                id: "er2-c2",
                comment: comment(
                    id: "er2-c2",
                    memberId: "u3",
                    content: "Filtered water made a huge difference for my calatheas as well.",
                    createdAtOffset: -1_500,
                    likeCount: 4
                ),
                replies: [
                    comment(
                        id: "er2-r1",
                        memberId: "u7",
                        content: "Same here — tap water was the hidden culprit.",
                        createdAtOffset: -1_100,
                        likeCount: 1
                    )
                ]
            ),
        ],
        "er3": [
            PostCommentThread(
                id: "er3-c1",
                comment: comment(
                    id: "er3-c1",
                    memberId: "u15",
                    content: "Airy mix after root rot scare was the turning point for my lyrata too.",
                    createdAtOffset: -4_200,
                    likeCount: 8
                ),
                replies: [
                    comment(
                        id: "er3-r1",
                        memberId: "u13",
                        content: "Hoping the brown spots stop spreading — thanks for the encouragement.",
                        createdAtOffset: -3_600,
                        likeCount: 3
                    )
                ]
            ),
            PostCommentThread(
                id: "er3-c2",
                comment: comment(
                    id: "er3-c2",
                    memberId: "u4",
                    content: "Check the drainage hole isn't blocked — learned that the hard way.",
                    createdAtOffset: -2_100,
                    likeCount: 2
                ),
                replies: []
            ),
        ],
        "er4": [
            PostCommentThread(
                id: "er4-c1",
                comment: comment(
                    id: "er4-c1",
                    memberId: "u3",
                    content: "Peace lilies are so dramatic — mine perks up within an hour of a soak.",
                    createdAtOffset: -2_800,
                    likeCount: 7,
                    isLiked: true
                ),
                replies: []
            ),
            PostCommentThread(
                id: "er4-c2",
                comment: comment(
                    id: "er4-c2",
                    memberId: "u16",
                    content: "Slow soak from the bottom works wonders on hot balcony days.",
                    createdAtOffset: -1_400,
                    likeCount: 3
                ),
                replies: []
            ),
        ],
        "sc1": [
            PostCommentThread(
                id: "sc1-c1",
                comment: comment(
                    id: "sc1-c1",
                    memberId: "u9",
                    content: "That stress blush is gorgeous — mineral grit changed my echeverias too.",
                    createdAtOffset: -1_600,
                    likeCount: 4
                ),
                replies: []
            ),
            PostCommentThread(
                id: "sc1-c2",
                comment: comment(
                    id: "sc1-c2",
                    memberId: "u15",
                    content: "Deep infrequent watering is the way. Overwatering was my rookie mistake.",
                    createdAtOffset: -900,
                    likeCount: 2
                ),
                replies: []
            ),
        ],
        "sc2": [
            PostCommentThread(
                id: "sc2-c1",
                comment: comment(
                    id: "sc2-c1",
                    memberId: "u11",
                    content: "Bottom watering saved my pearls from crown rot — strands look amazing.",
                    createdAtOffset: -2_200,
                    likeCount: 9
                ),
                replies: [
                    comment(
                        id: "sc2-r1",
                        memberId: "u4",
                        content: "How long do you let them sit in the tray?",
                        createdAtOffset: -1_700,
                        likeCount: 1
                    )
                ]
            ),
            PostCommentThread(
                id: "sc2-c2",
                comment: comment(
                    id: "sc2-c2",
                    memberId: "u2",
                    content: "No shriveled beads is the dream. Beautiful spill over the rim.",
                    createdAtOffset: -1_000,
                    likeCount: 5
                ),
                replies: []
            ),
        ],
        "sc3": [
            PostCommentThread(
                id: "sc3-c1",
                comment: comment(
                    id: "sc3-c1",
                    memberId: "u2",
                    content: "Zebra haworthia is the perfect desk plant — nearly indestructible.",
                    createdAtOffset: -1_800,
                    likeCount: 3
                ),
                replies: []
            ),
            PostCommentThread(
                id: "sc3-c2",
                comment: comment(
                    id: "sc3-c2",
                    memberId: "u15",
                    content: "Morning sun only — learned that after a crispy summer experiment.",
                    createdAtOffset: -1_100,
                    likeCount: 2,
                    isLiked: true
                ),
                replies: []
            ),
        ],
        "sc4": [
            PostCommentThread(
                id: "sc4-c1",
                comment: comment(
                    id: "sc4-c1",
                    memberId: "u9",
                    content: "Etiolation is so sneaky in winter corners. Brightest window gang.",
                    createdAtOffset: -2_500,
                    likeCount: 4
                ),
                replies: [
                    comment(
                        id: "sc4-r1",
                        memberId: "u15",
                        content: "New growth stacking tighter already — worth the shuffle.",
                        createdAtOffset: -2_000,
                        likeCount: 2
                    )
                ]
            ),
            PostCommentThread(
                id: "sc4-c2",
                comment: comment(
                    id: "sc4-c2",
                    memberId: "u2",
                    content: "Give it a week of morning direct sun and those nodes will tighten up.",
                    createdAtOffset: -1_300,
                    likeCount: 3
                ),
                replies: []
            ),
        ],
        "nl1": [
            PostCommentThread(
                id: "nl1-c1",
                comment: comment(
                    id: "nl1-c1",
                    memberId: "u6",
                    content: "That fenestration opening on day 5 — so worth the November wait.",
                    createdAtOffset: -1_200,
                    likeCount: 6
                ),
                replies: [
                    comment(
                        id: "nl1-r1",
                        memberId: "u1",
                        content: "Every three weeks during growing season for fertilizer here.",
                        createdAtOffset: -900,
                        likeCount: 2
                    )
                ]
            ),
            PostCommentThread(
                id: "nl1-c2",
                comment: comment(
                    id: "nl1-c2",
                    memberId: "u12",
                    content: "Unfurl season is the best season. Moss pole next?",
                    createdAtOffset: -600,
                    likeCount: 4,
                    isLiked: true
                ),
                replies: []
            ),
        ],
        "nl2": [
            PostCommentThread(
                id: "nl2-c1",
                comment: comment(
                    id: "nl2-c1",
                    memberId: "u7",
                    content: "Double spear flush is classic Alocasia energy — humidity crew approves.",
                    createdAtOffset: -2_000,
                    likeCount: 11
                ),
                replies: []
            ),
            PostCommentThread(
                id: "nl2-c2",
                comment: comment(
                    id: "nl2-c2",
                    memberId: "u1",
                    content: "65% humidity is the sweet spot. My Polly puts out twins every spring.",
                    createdAtOffset: -1_400,
                    likeCount: 7
                ),
                replies: [
                    comment(
                        id: "nl2-r1",
                        memberId: "u6",
                        content: "Exactly — top inch dry and we're good.",
                        createdAtOffset: -1_000,
                        likeCount: 3
                    )
                ]
            ),
        ],
        "nl3": [
            PostCommentThread(
                id: "nl3-c1",
                comment: comment(
                    id: "nl3-c1",
                    memberId: "u3",
                    content: "More white variegation after the east window move — makes sense.",
                    createdAtOffset: -1_700,
                    likeCount: 5
                ),
                replies: []
            ),
            PostCommentThread(
                id: "nl3-c2",
                comment: comment(
                    id: "nl3-c2",
                    memberId: "u6",
                    content: "Marble Queen loves bright indirect. Gorgeous new leaf.",
                    createdAtOffset: -1_000,
                    likeCount: 4,
                    isLiked: true
                ),
                replies: []
            ),
        ],
        "nl4": [
            PostCommentThread(
                id: "nl4-c1",
                comment: comment(
                    id: "nl4-c1",
                    memberId: "u6",
                    content: "Three new aerial roots in a week — the pole is doing its job.",
                    createdAtOffset: -2_300,
                    likeCount: 8
                ),
                replies: [
                    comment(
                        id: "nl4-r1",
                        memberId: "u12",
                        content: "First time it feels truly anchored is such a milestone.",
                        createdAtOffset: -1_800,
                        likeCount: 4
                    )
                ]
            ),
            PostCommentThread(
                id: "nl4-c2",
                comment: comment(
                    id: "nl4-c2",
                    memberId: "u10",
                    content: "Adansonii fenestration on fresh leaves never gets old.",
                    createdAtOffset: -1_200,
                    likeCount: 3
                ),
                replies: []
            ),
        ],
        "bi1": [
            PostCommentThread(
                id: "bi1-c1",
                comment: comment(
                    id: "bi1-c1",
                    memberId: "u1",
                    content: "East rail + afternoon shade is fern heaven. Mist on dry days is key.",
                    createdAtOffset: -1_900,
                    likeCount: 5
                ),
                replies: []
            ),
            PostCommentThread(
                id: "bi1-c2",
                comment: comment(
                    id: "bi1-c2",
                    memberId: "u16",
                    content: "Boston fern on a breezy balcony — brave and beautiful.",
                    createdAtOffset: -1_100,
                    likeCount: 3
                ),
                replies: []
            ),
        ],
        "bi2": [
            PostCommentThread(
                id: "bi2-c1",
                comment: comment(
                    id: "bi2-c1",
                    memberId: "u5",
                    content: "Basil up top for full sun is chef's kiss. Pinching flowers weekly helps.",
                    createdAtOffset: -2_100,
                    likeCount: 6
                ),
                replies: []
            ),
            PostCommentThread(
                id: "bi2-c2",
                comment: comment(
                    id: "bi2-c2",
                    memberId: "u11",
                    content: "Tiered shelf setup is smart — rosemary stays happier lower down.",
                    createdAtOffset: -1_300,
                    likeCount: 4,
                    isLiked: true
                ),
                replies: []
            ),
        ],
        "bi3": [
            PostCommentThread(
                id: "bi3-c1",
                comment: comment(
                    id: "bi3-c1",
                    memberId: "u4",
                    content: "Five pups for the swap — you're the propagation hero we need.",
                    createdAtOffset: -1_800,
                    likeCount: 7
                ),
                replies: [
                    comment(
                        id: "bi3-r1",
                        memberId: "u11",
                        content: "Neighborhood swap is this Saturday if you have extras!",
                        createdAtOffset: -1_400,
                        likeCount: 2
                    )
                ]
            ),
            PostCommentThread(
                id: "bi3-c2",
                comment: comment(
                    id: "bi3-c2",
                    memberId: "u3",
                    content: "Spider plants handle balcony breeze if you water before peak heat.",
                    createdAtOffset: -900,
                    likeCount: 3
                ),
                replies: []
            ),
        ],
        "bi4": [
            PostCommentThread(
                id: "bi4-c1",
                comment: comment(
                    id: "bi4-c1",
                    memberId: "u8",
                    content: "7am deep soak before a 95°F week — that's the balcony survival playbook.",
                    createdAtOffset: -2_400,
                    likeCount: 5
                ),
                replies: []
            ),
            PostCommentThread(
                id: "bi4-c2",
                comment: comment(
                    id: "bi4-c2",
                    memberId: "u5",
                    content: "Geranium up front for color, ivy trailing — classic rail combo.",
                    createdAtOffset: -1_500,
                    likeCount: 4
                ),
                replies: [
                    comment(
                        id: "bi4-r1",
                        memberId: "u16",
                        content: "They made it through the heat wave — relief!",
                        createdAtOffset: -1_100,
                        likeCount: 2
                    )
                ]
            ),
        ],
    ]
}
