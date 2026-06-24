import SwiftUI
import UIKit

// MARK: - Garden plot

enum GardenPlot: String, CaseIterable, Identifiable, Codable {
    case yellowLeafER = "yellow_leaf_er"
    case succulentCorner = "succulent_corner"
    case newLeafWatch = "new_leaf_watch"
    case balconyInspo = "balcony_inspo"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yellowLeafER:     return "Yellow Leaf ER"
        case .succulentCorner:  return "Succulent Corner"
        case .newLeafWatch:     return "New Leaf Watch"
        case .balconyInspo:     return "Balcony Inspiration"
        }
    }

    var subtitle: String {
        switch self {
        case .yellowLeafER:     return "Plants needing a little TLC"
        case .succulentCorner:  return "Dry-loving gems & tiny worlds"
        case .newLeafWatch:     return "Fresh unfurlings & growth logs"
        case .balconyInspo:     return "Outdoor nooks & sun-soaked setups"
        }
    }

    var icon: String {
        switch self {
        case .yellowLeafER:     return "cross.case.fill"
        case .succulentCorner:  return "circle.hexagongrid.fill"
        case .newLeafWatch:     return "arrow.triangle.2.circlepath"
        case .balconyInspo:     return "sun.max.fill"
        }
    }
}

// MARK: - Plant status

enum PlantStatus: String, CaseIterable, Identifiable, Codable {
    case thriving
    case recovering
    case sprouting
    case resting

    var id: String { rawValue }

    var label: String {
        switch self {
        case .thriving:   return "Thriving"
        case .recovering: return "Recovering"
        case .sprouting:  return "Sprouting"
        case .resting:    return "Resting"
        }
    }

    var symbol: String {
        switch self {
        case .thriving:   return "checkmark.seal.fill"
        case .recovering: return "cross.case.fill"
        case .sprouting:  return "tree.fill"
        case .resting:    return "moon.zzz.fill"
        }
    }
}

// MARK: - Specimen card layout

enum SpecimenStature: CaseIterable {
    case sprout
    case bloom
    case vine

    var imageAspect: CGFloat {
        switch self {
        case .sprout: return 0.82
        case .bloom:  return 1.18
        case .vine:   return 1.0
        }
    }
}

// MARK: - Specimen post

struct SpecimenPost: Identifiable {
    let id: String
    let plantName: String
    let scientificName: String?
    let caption: String
    var localImage: UIImage?
    /// Bundled asset in Assets.xcassets; preferred over remote URLs for curated mock posts.
    var imageAssetName: String?
    let status: PlantStatus
    let plot: GardenPlot
    let author: PostCardUser
    let createdAt: Date
    var likeCount: Int
    var commentCount: Int
    var isLiked: Bool
    var isSaved: Bool
    let stature: SpecimenStature
    var plantTags: [String]

    init(
        id: String,
        plantName: String,
        scientificName: String?,
        caption: String,
        localImage: UIImage? = nil,
        imageAssetName: String? = nil,
        status: PlantStatus,
        plot: GardenPlot,
        author: PostCardUser,
        createdAt: Date,
        likeCount: Int,
        commentCount: Int,
        isLiked: Bool,
        isSaved: Bool = false,
        stature: SpecimenStature,
        plantTags: [String] = []
    ) {
        self.id = id
        self.plantName = plantName
        self.scientificName = scientificName
        self.caption = caption
        self.localImage = localImage
        self.imageAssetName = imageAssetName
        self.status = status
        self.plot = plot
        self.author = author
        self.createdAt = createdAt
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.isLiked = isLiked
        self.isSaved = isSaved
        self.stature = stature
        self.plantTags = plantTags
    }
}

// MARK: - Garden pulse

struct GardenPulse {
    let summary: String
    let newLeavesToday: Int
    let helpRequests: Int
    let activeGardeners: Int
}

// MARK: - Mock data

enum GardenHomeMockData {

    static let posts: [SpecimenPost] = (
        yellowLeafERPosts +
        succulentCornerPosts +
        newLeafWatchPosts +
        balconyInspoPosts
    ).sorted { $0.createdAt > $1.createdAt }

    // MARK: - Yellow Leaf ER

    private static let yellowLeafERPosts: [SpecimenPost] = [
        SpecimenPost(
            id: "er1",
            plantName: "Golden Pothos",
            scientificName: "Epipremnum aureum",
            caption: "Two lower leaves yellowed after the pot sat beside the AC vent for a week. Upper vines still firm — moved it back and waiting for the top inch of soil to dry before watering again.",
            imageAssetName: MockPlantImages.erGoldenPothosYellow,
            status: .recovering,
            plot: .yellowLeafER,
            author: GardenCommunityProfiles.postCardUser(id: "u3"),
            createdAt: Date().addingTimeInterval(-3_600),
            likeCount: 18,
            commentCount: 9,
            isLiked: false,
            stature: .vine,
            plantTags: ["Pothos", "YellowLeaf", "ColdDraft", "PlantER"]
        ),
        SpecimenPost(
            id: "er2",
            plantName: "Calathea Orbifolia",
            scientificName: "Calathea orbifolia",
            caption: "Crispy brown tips showed up when indoor humidity dropped below 40%. Switched to filtered water, added a pebble tray, and grouped it with my ferns — no new damage in 4 days.",
            imageAssetName: MockPlantImages.erCalatheaCrispyEdges,
            status: .recovering,
            plot: .yellowLeafER,
            author: GardenCommunityProfiles.postCardUser(id: "u7"),
            createdAt: Date().addingTimeInterval(-8_400),
            likeCount: 29,
            commentCount: 14,
            isLiked: false,
            stature: .bloom,
            plantTags: ["Calathea", "CrispyEdges", "LowHumidity", "PlantER"]
        ),
        SpecimenPost(
            id: "er3",
            plantName: "Fiddle Leaf Fig",
            scientificName: "Ficus lyrata",
            caption: "Dark brown patches with yellow halos on the lowest leaves — roots at the edge of the pot were brown and soft. Repotted into airy mix and only watering when the top 2 inches are dry.",
            imageAssetName: MockPlantImages.erFiddleLeafBrownSpots,
            status: .recovering,
            plot: .yellowLeafER,
            author: GardenCommunityProfiles.postCardUser(id: "u13"),
            createdAt: Date().addingTimeInterval(-12_600),
            likeCount: 42,
            commentCount: 17,
            isLiked: false,
            stature: .bloom,
            plantTags: ["FiddleLeafFig", "Overwatering", "RootRot", "HelpNeeded"]
        ),
        SpecimenPost(
            id: "er4",
            plantName: "Peace Lily",
            scientificName: "Spathiphyllum",
            caption: "Completely wilted by noon — soil was pulled away from the pot edges. Slow soak brought the leaves back upright by evening. These tell you fast when they are thirsty.",
            imageAssetName: MockPlantImages.erPeaceLilyWilt,
            status: .recovering,
            plot: .yellowLeafER,
            author: GardenCommunityProfiles.postCardUser(id: "u14"),
            createdAt: Date().addingTimeInterval(-16_200),
            likeCount: 24,
            commentCount: 11,
            isLiked: true,
            stature: .sprout,
            plantTags: ["PeaceLily", "Underwatering", "Wilting", "PlantER"]
        ),
    ]

    // MARK: - Succulent Corner

    private static let succulentCornerPosts: [SpecimenPost] = [
        SpecimenPost(
            id: "sc1",
            plantName: "Echeveria",
            scientificName: "Echeveria elegans",
            caption: "Repotted into 70% mineral grit with a drainage hole last month. Rosettes tightened and the pink stress blush came back once I switched to deep, infrequent watering.",
            imageAssetName: MockPlantImages.scEcheveriaRosette,
            status: .thriving,
            plot: .succulentCorner,
            author: GardenCommunityProfiles.postCardUser(id: "u2"),
            createdAt: Date().addingTimeInterval(-2_400),
            likeCount: 21,
            commentCount: 3,
            isLiked: true,
            stature: .sprout,
            plantTags: ["Echeveria", "Succulents", "GrittyMix", "WellDraining"]
        ),
        SpecimenPost(
            id: "sc2",
            plantName: "String of Pearls",
            scientificName: "Senecio rowleyanus",
            caption: "Bottom watering when the pearls feel slightly soft — about every 10–14 days here. Strands finally spilling over the rim with no shriveled beads.",
            imageAssetName: MockPlantImages.scStringOfPearlsTrailing,
            status: .thriving,
            plot: .succulentCorner,
            author: GardenCommunityProfiles.postCardUser(id: "u4"),
            createdAt: Date().addingTimeInterval(-6_000),
            likeCount: 63,
            commentCount: 8,
            isLiked: false,
            stature: .bloom,
            plantTags: ["StringOfPearls", "Succulents", "BottomWatering", "Trailing"]
        ),
        SpecimenPost(
            id: "sc3",
            plantName: "Haworthia",
            scientificName: "Haworthia fasciata",
            caption: "Zebra haworthia on an east windowsill — a few hours of morning sun, watered roughly every three weeks. Compact offsets forming with almost no maintenance.",
            imageAssetName: MockPlantImages.scHaworthiaZebra,
            status: .thriving,
            plot: .succulentCorner,
            author: GardenCommunityProfiles.postCardUser(id: "u9"),
            createdAt: Date().addingTimeInterval(-10_800),
            likeCount: 38,
            commentCount: 2,
            isLiked: false,
            stature: .vine,
            plantTags: ["Haworthia", "DeskPlant", "Succulents", "MorningSun"]
        ),
        SpecimenPost(
            id: "sc4",
            plantName: "Jade Plant",
            scientificName: "Crassula ovata",
            caption: "Leggy stems from a dim winter corner — leaves spaced far apart on stretched nodes. Moved to the brightest window; new growth is already stacking tighter.",
            imageAssetName: MockPlantImages.scJadeEtiolationRecovery,
            status: .recovering,
            plot: .succulentCorner,
            author: GardenCommunityProfiles.postCardUser(id: "u15"),
            createdAt: Date().addingTimeInterval(-15_600),
            likeCount: 31,
            commentCount: 6,
            isLiked: false,
            stature: .sprout,
            plantTags: ["JadePlant", "Succulents", "Etiolation", "BrightLight"]
        ),
    ]

    // MARK: - New Leaf Watch

    private static let newLeafWatchPosts: [SpecimenPost] = [
        SpecimenPost(
            id: "nl1",
            plantName: "Monstera",
            scientificName: "Monstera deliciosa",
            caption: "Day 5 of unfurling — the new leaf is still rolled but the first fenestration slits are opening. Worth the wait since November dormancy.",
            imageAssetName: MockPlantImages.nlMonsteraUnfurlMacro,
            status: .sprouting,
            plot: .newLeafWatch,
            author: GardenCommunityProfiles.postCardUser(id: "u1"),
            createdAt: Date().addingTimeInterval(-1_800),
            likeCount: 34,
            commentCount: 5,
            isLiked: false,
            stature: .bloom,
            plantTags: ["Monstera", "NewLeaf", "Unfurling", "AroidGang"]
        ),
        SpecimenPost(
            id: "nl2",
            plantName: "Alocasia Polly",
            scientificName: "Alocasia × amazonica",
            caption: "Two spear tips pushing up at once — classic Alocasia flush. Humidity around 65% and watering when the top inch of soil dries.",
            imageAssetName: MockPlantImages.nlAlocasiaSpearsTopdown,
            status: .sprouting,
            plot: .newLeafWatch,
            author: GardenCommunityProfiles.postCardUser(id: "u6"),
            createdAt: Date().addingTimeInterval(-5_400),
            likeCount: 87,
            commentCount: 12,
            isLiked: true,
            stature: .vine,
            plantTags: ["Alocasia", "NewLeaf", "GrowthLog", "Humidity"]
        ),
        SpecimenPost(
            id: "nl3",
            plantName: "Pothos Marble Queen",
            scientificName: "Epipremnum aureum",
            caption: "The newest leaf at the vine tip is opening with more white variegation after I moved it closer to an east window — still no direct midday sun.",
            imageAssetName: MockPlantImages.nlPothosVariegationLifestyle,
            status: .sprouting,
            plot: .newLeafWatch,
            author: GardenCommunityProfiles.postCardUser(id: "u10"),
            createdAt: Date().addingTimeInterval(-9_600),
            likeCount: 71,
            commentCount: 11,
            isLiked: false,
            stature: .sprout,
            plantTags: ["Pothos", "Variegation", "NewLeaf", "BrightLight"]
        ),
        SpecimenPost(
            id: "nl4",
            plantName: "Monstera Adansonii",
            scientificName: "Monstera adansonii",
            caption: "Fresh perforated leaf plus three new aerial roots gripping the moss pole this week. First time the vine feels truly anchored and climbing.",
            imageAssetName: MockPlantImages.nlAdansoniiMossPoleWide,
            status: .sprouting,
            plot: .newLeafWatch,
            author: GardenCommunityProfiles.postCardUser(id: "u12"),
            createdAt: Date().addingTimeInterval(-14_400),
            likeCount: 58,
            commentCount: 9,
            isLiked: true,
            stature: .vine,
            plantTags: ["Monstera", "MossPole", "NewLeaf", "Climbing"]
        ),
    ]

    // MARK: - Balcony Inspiration

    private static let balconyInspoPosts: [SpecimenPost] = [
        SpecimenPost(
            id: "bi1",
            plantName: "Boston Fern",
            scientificName: "Nephrolepis exaltata",
            caption: "East-facing balcony rail — soft morning light, shaded by 2pm. I mist the fronds on dry days and keep it out of direct afternoon sun.",
            imageAssetName: MockPlantImages.biBostonFernBalcony,
            status: .resting,
            plot: .balconyInspo,
            author: GardenCommunityProfiles.postCardUser(id: "u5"),
            createdAt: Date().addingTimeInterval(-4_200),
            likeCount: 41,
            commentCount: 4,
            isLiked: false,
            stature: .sprout,
            plantTags: ["BostonFern", "BalconyGarden", "MorningSun", "OutdoorSetup"]
        ),
        SpecimenPost(
            id: "bi2",
            plantName: "Basil & Rosemary",
            scientificName: nil,
            caption: "South-facing tiered shelf — basil up top for full sun, rosemary below where it stays cooler. Pinch basil flowers weekly to keep leaves tender.",
            imageAssetName: MockPlantImages.biHerbsTieredShelf,
            status: .thriving,
            plot: .balconyInspo,
            author: GardenCommunityProfiles.postCardUser(id: "u8"),
            createdAt: Date().addingTimeInterval(-7_800),
            likeCount: 52,
            commentCount: 6,
            isLiked: false,
            stature: .sprout,
            plantTags: ["Basil", "Rosemary", "EdibleGarden", "BalconyGarden"]
        ),
        SpecimenPost(
            id: "bi3",
            plantName: "Spider Plant",
            scientificName: "Chlorophytum comosum",
            caption: "Railing planter loaded with pups — cut five babies for the neighborhood swap. Handles breezy balcony life if I water before the hottest afternoons.",
            imageAssetName: MockPlantImages.biSpiderPlantRailing,
            status: .thriving,
            plot: .balconyInspo,
            author: GardenCommunityProfiles.postCardUser(id: "u11"),
            createdAt: Date().addingTimeInterval(-11_400),
            likeCount: 44,
            commentCount: 7,
            isLiked: false,
            stature: .bloom,
            plantTags: ["SpiderPlant", "BalconyGarden", "Propagation", "PlantSwap"]
        ),
        SpecimenPost(
            id: "bi4",
            plantName: "Geranium & Trailing Ivy",
            scientificName: "Pelargonium × hortorum",
            caption: "Red geranium up front for color, English ivy trailing down the rail. A deep soak at 7am got them through a 95°F week without crisping.",
            imageAssetName: MockPlantImages.biGeraniumIvyRailing,
            status: .thriving,
            plot: .balconyInspo,
            author: GardenCommunityProfiles.postCardUser(id: "u16"),
            createdAt: Date().addingTimeInterval(-19_800),
            likeCount: 36,
            commentCount: 5,
            isLiked: false,
            stature: .vine,
            plantTags: ["Geranium", "EnglishIvy", "ContainerGarden", "HeatWave"]
        ),
    ]

    static func pulse(for posts: [SpecimenPost]) -> GardenPulse {
        let newLeaves = posts.filter { $0.status == .sprouting }.count
        let helpRequests = posts.filter { $0.plot == .yellowLeafER }.count
        let gardeners = Set(posts.map(\.author.id)).count
        let succulentThriving = posts.contains { $0.plot == .succulentCorner && $0.status == .thriving }

        let summary: String
        if posts.isEmpty {
            summary = "The garden is quiet right now — share the first specimen of the day."
        } else if succulentThriving {
            summary = "\(newLeaves) new leaves unfurling today · \(helpRequests) plants in the ER · Succulent Corner is quietly blooming."
        } else {
            summary = "\(newLeaves) new leaves unfurling today · \(helpRequests) plants in the ER · \(gardeners) gardeners checked in."
        }

        return GardenPulse(
            summary: summary,
            newLeavesToday: newLeaves,
            helpRequests: helpRequests,
            activeGardeners: gardeners
        )
    }

    static func postCount(for plot: GardenPlot, in posts: [SpecimenPost]) -> Int {
        posts.filter { $0.plot == plot }.count
    }

    /// Plant-linked tags across the feed, ranked by frequency (for the trending row).
    /// Topic tags such as `BalconyGarden` are excluded because they have no encyclopedia entry.
    static func trendingTags(in posts: [SpecimenPost], limit: Int = 8) -> [String] {
        var counts: [String: Int] = [:]
        for post in posts {
            for tag in post.plantTags where PlantWikiModel.isPlantTag(tag) {
                counts[tag, default: 0] += 1
            }
        }
        return counts
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
            }
            .prefix(limit)
            .map(\.key)
    }
}
