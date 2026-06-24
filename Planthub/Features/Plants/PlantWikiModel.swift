import SwiftUI

struct PlantWikiCategory: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let intro: String
}

enum PlantDifficulty: String, CaseIterable, Hashable {
    case easy = "Beginner Friendly"
    case medium = "Intermediate Care"
    case hard = "Advanced Care"
}

struct PlantFAQ: Identifiable, Hashable {
    let id: String
    let question: String
    let answer: String
}

struct PlantWikiPlant: Identifiable, Hashable {
    let id: String
    let name: String
    let scientificName: String
    /// Non-empty when a local asset exists in Assets.xcassets.
    let imageName: String
    let categoryIDs: [String]
    let summary: String
    let difficulty: PlantDifficulty
    let light: String
    let water: String
    let temperature: String
    let soil: String
    let careGuide: String
    let cautions: String
    let tags: [String]
    let faqs: [PlantFAQ]
}

enum PlantWikiModel {
    private typealias PlantSeed = (
        id: String,
        name: String,
        scientificName: String,
        keyword: String,
        difficulty: PlantDifficulty,
        summary: String,
        tags: [String]
    )

    static let categories: [PlantWikiCategory] = [
        .init(
            id: "foliage",
            title: "Foliage Plants",
            icon: "tree.fill",
            intro: "Leaf shape and texture take center stage. Great for living rooms, workspaces, and calm corners."
        ),
        .init(
            id: "succulent",
            title: "Succulent Plants",
            icon: "sun.max.fill",
            intro: "Water-storing plants that prefer bright light and fast-draining soil."
        ),
        .init(
            id: "flowering",
            title: "Flowering Plants",
            icon: "camera.macro",
            intro: "Bloom-focused species that add color and rhythm to indoor spaces."
        ),
        .init(
            id: "vine",
            title: "Vining Plants",
            icon: "point.topleft.down.curvedto.point.bottomright.up",
            intro: "Trailing and climbing plants that bring movement and vertical layering."
        ),
        .init(
            id: "hydro",
            title: "Hydroponic Plants",
            icon: "drop.fill",
            intro: "Clean water-based setups that highlight roots and minimal design."
        ),
        .init(
            id: "herb",
            title: "Herb Plants",
            icon: "takeoutbag.and.cup.and.straw.fill",
            intro: "Fragrant, edible herbs suited for kitchen windows and daily cooking."
        )
    ]

    static let plants: [PlantWikiPlant] =
        makePlants(from: foliageSeeds, categoryID: "foliage")
        + makePlants(from: succulentSeeds, categoryID: "succulent")
        + makePlants(from: floweringSeeds, categoryID: "flowering")
        + makePlants(from: vineSeeds, categoryID: "vine")
        + makePlants(from: hydroSeeds, categoryID: "hydro")
        + makePlants(from: herbSeeds, categoryID: "herb")

    static func plants(in categoryID: String) -> [PlantWikiPlant] {
        if categoryID.isEmpty {
            return plants
        }
        return plants.filter { $0.categoryIDs.contains(categoryID) }
    }

    static func category(by id: String) -> PlantWikiCategory {
        categories.first(where: { $0.id == id }) ?? categories[0]
    }

    static func plant(id: String) -> PlantWikiPlant? {
        plants.first { $0.id == id }
    }

    static func plant(named name: String) -> PlantWikiPlant? {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        if let exactMatch = plants.first(where: {
            $0.name.caseInsensitiveCompare(normalized) == .orderedSame
                || $0.scientificName.caseInsensitiveCompare(normalized) == .orderedSame
        }) {
            return exactMatch
        }

        return plants.first(where: {
            $0.name.localizedCaseInsensitiveContains(normalized)
                || $0.scientificName.localizedCaseInsensitiveContains(normalized)
        })
    }

    /// Resolves a feed hashtag (camelCase or alias) to a wiki plant record.
    /// Returns `nil` for topic tags such as `BalconyGarden` or `NewLeaf`.
    static func plant(forTag tag: String) -> PlantWikiPlant? {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let aliasTarget = tagAliases[trimmed] {
            return plant(named: aliasTarget)
        }

        if let direct = plant(named: trimmed) {
            return direct
        }

        let spaced = spacedTagName(trimmed)
        if spaced != trimmed, let spacedMatch = plant(named: spaced) {
            return spacedMatch
        }

        return nil
    }

    /// Whether a feed tag maps to a real encyclopedia entry (not a topic tag).
    static func isPlantTag(_ tag: String) -> Bool {
        plant(forTag: tag) != nil
    }

    /// Explicit mappings from Home feed hashtags to encyclopedia display names.
    private static let tagAliases: [String: String] = [
        "Basil": "Sweet Basil",
        "Haworthia": "Zebra Haworthia",
        "Calathea": "Calathea Orbifolia",
        "Alocasia": "Alocasia Polly",
        "Pothos": "Golden Pothos",
        "SpiderPlant": "Spider Plant",
        "BostonFern": "Boston Fern",
        "StringOfPearls": "String of Pearls",
        "EnglishIvy": "English Ivy",
        "JadePlant": "Jade Plant",
        "FiddleLeafFig": "Fiddle Leaf Fig",
        "PeaceLily": "Peace Lily",
        "Geranium": "Geranium"
    ]

    /// Inserts spaces before capital letters: `FiddleLeafFig` → `Fiddle Leaf Fig`.
    private static func spacedTagName(_ tag: String) -> String {
        guard !tag.contains(" ") else { return tag }

        var result = ""
        for (index, character) in tag.enumerated() {
            if character.isUppercase, index > 0 {
                let previousIndex = tag.index(tag.startIndex, offsetBy: index - 1)
                if !tag[previousIndex].isUppercase {
                    result.append(" ")
                }
            }
            result.append(character)
        }
        return result
    }

    /// Maps plant IDs to bundled asset names in Assets.xcassets.
    private static let localAssets: [String: String] = [
        // Foliage Plants
        "foliage-monstera":       "plant-monstera",
        "foliage-fiddle":         "plant-fiddle-leaf-fig",
        "foliage-calathea":       "plant-calathea-orbifolia",
        "foliage-aglaonema":      "plant-chinese-evergreen",
        "foliage-dieffenbachia":  "plant-dieffenbachia",
        "foliage-selloum":        "plant-split-leaf-philodendron",
        "foliage-alocasia":       "plant-alocasia-polly",
        "foliage-peperomia":      "plant-peperomia-obtusifolia",
        "foliage-dracaena":       "plant-dracaena-fragrans",
        "foliage-zz":             "plant-zz-plant",
        "foliage-boston":         "plant-boston-fern",
        "foliage-spider":         "plant-spider-plant",
        // Succulent Plants
        "succulent-aloe":         "plant-aloe-vera",
        "succulent-echeveria":    "plant-echeveria",
        "succulent-jade":         "plant-jade-plant",
        "succulent-haworthia":    "plant-zebra-haworthia",
        "succulent-panda":        "plant-panda-plant",
        "succulent-burro":        "plant-burros-tail",
        "succulent-lithops":      "plant-living-stones",
        "succulent-bunny-ear":    "plant-bunny-ear-cactus",
        "succulent-ladyfinger":   "plant-ladyfinger-cactus",
        "succulent-christmas":    "plant-christmas-cactus",
        // Vining Plants
        "vine-pothos":            "plant-golden-pothos",
        "vine-heartleaf":         "plant-heartleaf-philodendron",
        "vine-syngonium":         "plant-arrowhead-vine",
        "vine-hoya":              "plant-hoya-carnosa",
        "vine-adansonii":         "plant-swiss-cheese-vine",
        "vine-grape-ivy":         "plant-grape-ivy",
        "vine-english-ivy":       "plant-english-ivy",
        "vine-satin":             "plant-satin-pothos",
        "vine-inch":              "plant-tradescantia-zebrina",
        "vine-nickels":           "plant-string-of-nickels",
        "vine-pearls":            "plant-string-of-pearls",
        // Flowering Plants
        "flower-anthurium":       "plant-anthurium",
        "flower-peace-lily":      "plant-peace-lily",
        "flower-orchid":          "plant-phalaenopsis-orchid",
        "flower-violet":          "plant-african-violet",
        "flower-katy":            "plant-flaming-katy",
        "flower-hibiscus":        "plant-chinese-hibiscus",
        "flower-gardenia":        "plant-gardenia",
        "flower-jasmine":         "plant-arabian-jasmine",
        "flower-cyclamen":        "plant-cyclamen",
        "flower-begonia":         "plant-elatior-begonia",
        "flower-geranium":        "plant-geranium",
        // Hydroponic Plants
        "hydro-bamboo":           "plant-lucky-bamboo",
        "hydro-pothos":           "plant-hydro-pothos",
        "hydro-spider":           "plant-hydro-spider-plant",
        "hydro-syngonium":        "plant-hydro-arrowhead",
        "hydro-philodendron":     "plant-hydro-philodendron",
        "hydro-tradescantia":     "plant-hydro-inch-plant",
        "hydro-coleus":           "plant-hydro-coleus",
        "hydro-aglaonema":        "plant-hydro-chinese-evergreen",
        "hydro-ivy":              "plant-hydro-english-ivy",
        "hydro-mint":             "plant-hydro-mint",
        // Herb Plants
        "herb-basil":             "plant-sweet-basil",
        "herb-mint":              "plant-spearmint",
        "herb-rosemary":          "plant-rosemary",
        "herb-thyme":             "plant-thyme",
        "herb-oregano":           "plant-oregano",
        "herb-parsley":           "plant-parsley",
        "herb-chives":            "plant-chives",
        "herb-lemongrass":        "plant-lemongrass",
        "herb-cilantro":          "plant-cilantro",
        "herb-sage":              "plant-sage"
    ]

    static func fallbackPlant(named name: String) -> PlantWikiPlant {
        makePlant(
            id: "fallback-\(name.lowercased())",
            name: name,
            scientificName: "Unknown Species",
            keyword: name,
            categoryID: "foliage",
            difficulty: .medium,
            summary: "A placeholder profile. Add complete plant data in PlantWikiModel for this species.",
            tags: ["Data Pending", "Indoor Plant"],
            light: "Bright, indirect light.",
            water: "Water when the topsoil feels dry.",
            temperature: "18-28 C",
            soil: "Well-draining, airy potting mix.",
            careGuide: "Start with stable light and moderate watering. Observe leaf color and growth weekly.",
            cautions: "Avoid sudden environmental changes and overwatering.",
            faqs: [
                .init(
                    id: "fallback-faq-1",
                    question: "Why is this entry incomplete?",
                    answer: "This screen is using mock data. Add a full record in PlantWikiModel to complete it."
                )
            ]
        )
    }

    private static func makePlants(from seeds: [PlantSeed], categoryID: String) -> [PlantWikiPlant] {
        seeds.map { seed in
            let profile = careProfile(for: categoryID, difficulty: seed.difficulty)
            return makePlant(
                id: seed.id,
                name: seed.name,
                scientificName: seed.scientificName,
                keyword: seed.keyword,
                categoryID: categoryID,
                difficulty: seed.difficulty,
                summary: seed.summary,
                tags: seed.tags,
                light: profile.light,
                water: profile.water,
                temperature: profile.temperature,
                soil: profile.soil,
                careGuide: profile.careGuide,
                cautions: profile.cautions,
                faqs: defaultFAQs(for: seed.name)
            )
        }
    }

    private static func makePlant(
        id: String,
        name: String,
        scientificName: String,
        keyword: String,
        categoryID: String,
        difficulty: PlantDifficulty,
        summary: String,
        tags: [String],
        light: String,
        water: String,
        temperature: String,
        soil: String,
        careGuide: String,
        cautions: String,
        faqs: [PlantFAQ]
    ) -> PlantWikiPlant {
        PlantWikiPlant(
            id: id,
            name: name,
            scientificName: scientificName,
            imageName: localAssets[id] ?? "",
            categoryIDs: [categoryID],
            summary: summary,
            difficulty: difficulty,
            light: light,
            water: water,
            temperature: temperature,
            soil: soil,
            careGuide: careGuide,
            cautions: cautions,
            tags: tags,
            faqs: faqs
        )
    }

    private static func careProfile(
        for categoryID: String,
        difficulty: PlantDifficulty
    ) -> (light: String, water: String, temperature: String, soil: String, careGuide: String, cautions: String) {
        switch categoryID {
        case "foliage":
            return (
                "Bright to medium indirect light.",
                "Water when top 2-3 cm of soil is dry.",
                "18-30 C",
                "Rich, airy mix with perlite.",
                "Keep light stable and rotate the pot every two weeks for balanced growth.",
                "Overwatering and low airflow can cause yellow leaves and root issues."
            )
        case "succulent":
            return (
                "Strong light, with gentle direct sun.",
                "Soak and dry cycle; water only when fully dry.",
                "12-32 C",
                "Fast-draining cactus or gritty mix.",
                "Prioritize sunlight and airflow. Water deeply but infrequently.",
                "Excess moisture is the fastest path to rot."
            )
        case "flowering":
            return (
                "Bright indirect light; some species need direct morning sun.",
                "Keep lightly moist during active growth.",
                "16-30 C",
                "Fertile, well-draining mix.",
                "Use bloom fertilizer in growth season and remove spent flowers quickly.",
                "Sudden light or watering swings can reduce buds and bloom quality."
            )
        case "vine":
            return (
                "Medium to bright indirect light.",
                "Water when topsoil dries out.",
                "18-30 C",
                "Loose mix with good drainage.",
                "Prune tips regularly to keep plants compact and encourage branching.",
                "Long dry periods cause crisp edges; constant wet soil causes soft stems."
            )
        case "hydro":
            return (
                "Bright indirect light.",
                "Change water every 5-10 days.",
                "18-30 C",
                "Hydro setup with clean water and optional inert media.",
                "Rinse roots and container often, and keep water level just below stem nodes.",
                "Stagnant water and warm conditions can trigger root decay quickly."
            )
        case "herb":
            return (
                "4-6 hours of bright light daily.",
                "Keep soil evenly moist, never soggy.",
                "15-32 C",
                "Nutrient-rich, loose herb mix.",
                "Harvest frequently from the top to trigger fresh growth and fuller shape.",
                "Weak light and poor drainage reduce flavor and increase disease risk."
            )
        default:
            return (
                "Bright, indirect light.",
                "Water when topsoil feels dry.",
                "18-28 C",
                "Well-draining potting mix.",
                "Observe weekly and adjust slowly based on leaf and stem response.",
                "Avoid dramatic changes in light, watering, and temperature."
            )
        }
    }

    private static func defaultFAQs(for plantName: String) -> [PlantFAQ] {
        [
            .init(
                id: "\(plantName)-faq-1",
                question: "How often should I fertilize this plant?",
                answer: "Feed lightly every 2-4 weeks in spring and summer. Reduce or pause feeding in winter."
            ),
            .init(
                id: "\(plantName)-faq-2",
                question: "Why are leaves turning yellow?",
                answer: "The most common reasons are overwatering, low light, or poor airflow."
            ),
            .init(
                id: "\(plantName)-faq-3",
                question: "Can this plant stay in a bedroom?",
                answer: "Yes, if the room has enough light and regular ventilation."
            )
        ]
    }

    private static let foliageSeeds: [PlantSeed] = [
        ("foliage-monstera", "Monstera", "Monstera deliciosa", "monstera deliciosa", .easy, "A bold split-leaf plant that anchors modern indoor spaces.", ["Beginner Friendly", "Indoor Favorite", "Decorative"]),
        ("foliage-fiddle", "Fiddle Leaf Fig", "Ficus lyrata", "fiddle leaf fig", .medium, "Large sculptural leaves make this a statement plant for bright rooms.", ["Statement Plant", "Moderate Care", "Bright Spot"]),
        ("foliage-calathea", "Calathea Orbifolia", "Calathea orbifolia", "calathea orbifolia", .medium, "Soft striped foliage and a calm look for humid corners.", ["Humidity Lover", "Patterned Leaves", "Pet Friendly"]),
        ("foliage-aglaonema", "Chinese Evergreen", "Aglaonema commutatum", "aglaonema plant", .easy, "A dependable low-light foliage plant with patterned leaves.", ["Low Light", "Office Friendly", "Beginner Friendly"]),
        ("foliage-dieffenbachia", "Dieffenbachia", "Dieffenbachia seguine", "dieffenbachia plant", .medium, "Large variegated leaves bring contrast and volume indoors.", ["Variegated", "Moderate Care", "Indoor"]),
        ("foliage-selloum", "Split Leaf Philodendron", "Thaumatophyllum bipinnatifidum", "philodendron selloum", .easy, "Deeply cut leaves give a lush tropical look all year.", ["Tropical Look", "Beginner Friendly", "Fast Grower"]),
        ("foliage-alocasia", "Alocasia Polly", "Alocasia amazonica", "alocasia amazonica", .hard, "High-contrast arrow leaves with dramatic vein definition.", ["Advanced Care", "Humidity Sensitive", "Bold Foliage"]),
        ("foliage-peperomia", "Baby Rubber Plant", "Peperomia obtusifolia", "peperomia obtusifolia", .easy, "Compact glossy foliage ideal for desktops and shelves.", ["Compact", "Low Maintenance", "Beginner Friendly"]),
        ("foliage-dracaena", "Corn Plant", "Dracaena fragrans", "dracaena fragrans", .easy, "Upright form and arching leaves fit minimal interiors.", ["Indoor Classic", "Beginner Friendly", "Low Light Tolerant"]),
        ("foliage-zz", "ZZ Plant", "Zamioculcas zamiifolia", "zz plant", .easy, "Glossy, drought-tolerant foliage with very forgiving care.", ["Drought Tolerant", "Beginner Friendly", "Office Friendly"]),
        ("foliage-boston", "Boston Fern", "Nephrolepis exaltata", "boston fern", .medium, "Arching fronds that love humidity and filtered light on porches and balconies.", ["Humidity Lover", "Balcony Friendly", "Moderate Care"]),
        ("foliage-spider", "Spider Plant", "Chlorophytum comosum", "spider plant", .easy, "Striped arching leaves with easy pups for propagation and hanging displays.", ["Beginner Friendly", "Propagation", "Hanging Plant"])
    ]

    private static let succulentSeeds: [PlantSeed] = [
        ("succulent-aloe", "Aloe Vera", "Aloe vera", "aloe vera succulent", .easy, "A practical succulent with thick leaves and strong drought tolerance.", ["Beginner Friendly", "Sunny Window", "Drought Tolerant"]),
        ("succulent-echeveria", "Echeveria", "Echeveria elegans", "echeveria elegans", .medium, "Rosette succulent that colors up well under bright light.", ["Color Stress", "Succulent", "Moderate Care"]),
        ("succulent-jade", "Jade Plant", "Crassula ovata", "jade plant succulent", .easy, "Woody succulent that can be trained into a mini tree form.", ["Beginner Friendly", "Long Lived", "Bright Light"]),
        ("succulent-haworthia", "Zebra Haworthia", "Haworthia attenuata", "haworthia zebra", .easy, "Small striped succulent for desks and compact spaces.", ["Compact", "Beginner Friendly", "Low Water"]),
        ("succulent-panda", "Panda Plant", "Kalanchoe tomentosa", "kalanchoe tomentosa", .easy, "Velvety leaves and a soft texture with easy drought care.", ["Soft Texture", "Low Water", "Beginner Friendly"]),
        ("succulent-burro", "Burro's Tail", "Sedum morganianum", "burro tail succulent", .medium, "Trailing succulent stems ideal for hanging displays.", ["Trailing", "Succulent", "Moderate Care"]),
        ("succulent-lithops", "Living Stones", "Lithops karasmontana", "lithops", .hard, "Collector succulent with strict seasonal watering needs.", ["Advanced Care", "Collector Plant", "Very Low Water"]),
        ("succulent-bunny-ear", "Bunny Ear Cactus", "Opuntia microdasys", "bunny ear cactus", .easy, "Classic cactus form that thrives in strong sunlight.", ["Cactus", "Sunny Spot", "Drought Tolerant"]),
        ("succulent-ladyfinger", "Ladyfinger Cactus", "Mammillaria elongata", "mammillaria elongata", .easy, "Cluster-forming cactus that stays compact and tidy.", ["Compact", "Cactus", "Beginner Friendly"]),
        ("succulent-christmas", "Christmas Cactus", "Schlumbergera truncata", "christmas cactus", .medium, "Segmented succulent that can bloom indoors in cool seasons.", ["Blooming Succulent", "Moderate Care", "Seasonal Flower"])
    ]

    private static let floweringSeeds: [PlantSeed] = [
        ("flower-anthurium", "Anthurium", "Anthurium andraeanum", "anthurium flower", .medium, "Glossy foliage with long-lasting colorful spathes.", ["Long Bloom", "Decorative", "Moderate Care"]),
        ("flower-peace-lily", "Peace Lily", "Spathiphyllum wallisii", "peace lily", .easy, "Elegant white blooms and strong shade tolerance indoors.", ["Beginner Friendly", "Low Light", "Blooming"]),
        ("flower-orchid", "Phalaenopsis Orchid", "Phalaenopsis aphrodite", "phalaenopsis orchid", .medium, "Arching stems with refined blooms and long flower life.", ["Orchid", "Elegant", "Moderate Care"]),
        ("flower-violet", "African Violet", "Saintpaulia ionantha", "african violet", .medium, "Compact flowering plant for bright indoor windows.", ["Small Space", "Frequent Blooms", "Moderate Care"]),
        ("flower-katy", "Flaming Katy", "Kalanchoe blossfeldiana", "kalanchoe blossfeldiana", .easy, "Colorful clusters and simple care for bright shelves.", ["Beginner Friendly", "Blooming", "Low Water"]),
        ("flower-hibiscus", "Chinese Hibiscus", "Hibiscus rosa-sinensis", "hibiscus flower", .medium, "Large tropical flowers when given enough light and warmth.", ["Large Flowers", "Sun Lover", "Moderate Care"]),
        ("flower-gardenia", "Gardenia", "Gardenia jasminoides", "gardenia flower", .hard, "Fragrant white blooms with high humidity and soil demands.", ["Fragrant", "Advanced Care", "Acidic Soil"]),
        ("flower-jasmine", "Arabian Jasmine", "Jasminum sambac", "arabian jasmine", .medium, "Sweetly scented flowers with frequent flushes in bright light.", ["Fragrant", "Blooming", "Sun Lover"]),
        ("flower-cyclamen", "Cyclamen", "Cyclamen persicum", "cyclamen flower", .medium, "Cool-season flowers with distinctive upturned petals.", ["Cool Season", "Blooming", "Moderate Care"]),
        ("flower-begonia", "Elatior Begonia", "Begonia elatior", "elatior begonia", .medium, "Dense flowering habit with bright color options.", ["Blooming", "Compact", "Moderate Care"]),
        ("flower-geranium", "Geranium", "Pelargonium × hortorum", "geranium flower", .easy, "Bright balcony blooms that handle sun and heat with consistent watering.", ["Balcony Friendly", "Sun Lover", "Beginner Friendly"])
    ]

    private static let vineSeeds: [PlantSeed] = [
        ("vine-pothos", "Golden Pothos", "Epipremnum aureum", "golden pothos", .easy, "Golden-yellow variegated heart-shaped leaves trail fast from shelves, poles, or hanging pots.", ["Beginner Friendly", "Vining", "Low Light"]),
        ("vine-heartleaf", "Heartleaf Philodendron", "Philodendron hederaceum", "heartleaf philodendron", .easy, "Glossy solid-green heart-shaped leaves cascade softly from pots and shelves.", ["Beginner Friendly", "Vining", "Indoor Classic"]),
        ("vine-syngonium", "Arrowhead Vine", "Syngonium podophyllum", "syngonium vine", .easy, "Cream-and-green arrow-shaped leaves on an adaptive vine that responds well to pruning.", ["Vining", "Beginner Friendly", "Fast Grower"]),
        ("vine-hoya", "Wax Plant", "Hoya carnosa", "hoya carnosa vine", .medium, "Thick waxy oval leaves and star-shaped pink flower clusters on trailing stems.", ["Vining", "Bloom Potential", "Moderate Care"]),
        ("vine-adansonii", "Swiss Cheese Vine", "Monstera adansonii", "monstera adansonii", .medium, "Small perforated heart-shaped leaves on a lightweight climbing vine.", ["Vining", "Decorative", "Moderate Care"]),
        ("vine-grape-ivy", "Grape Ivy", "Cissus rhombifolia", "grape ivy", .medium, "Glossy diamond-shaped three-leaflet vines form dense cascades on shelves and walls.", ["Vining", "Layered Decor", "Moderate Care"]),
        ("vine-english-ivy", "English Ivy", "Hedera helix", "english ivy vine", .medium, "Deeply lobed classic ivy leaves trail and climb with vigorous spreading growth.", ["Vining", "Classic Look", "Moderate Care"]),
        ("vine-satin", "Satin Pothos", "Scindapsus pictus", "satin pothos", .easy, "Velvety dark leaves splashed with shimmering silver trail from pots and ledges.", ["Vining", "Beginner Friendly", "Decorative Leaves"]),
        ("vine-inch", "Inch Plant", "Tradescantia zebrina", "tradescantia zebrina", .easy, "Metallic purple-and-silver striped leaves trail rapidly with vivid color contrast.", ["Fast Grower", "Vining", "Easy Propagation"]),
        ("vine-nickels", "String of Nickels", "Dischidia nummularia", "dischidia nummularia", .medium, "Tiny round coin-shaped leaves on delicate thread-like hanging stems.", ["Trailing", "Moderate Care", "Compact Vine"]),
        ("vine-pearls", "String of Pearls", "Senecio rowleyanus", "string of pearls", .medium, "Bead-like leaves on cascading stems — a classic trailing succulent for bright shelves.", ["Trailing", "Succulent", "Moderate Care"])
    ]

    private static let hydroSeeds: [PlantSeed] = [
        ("hydro-bamboo", "Lucky Bamboo", "Dracaena sanderiana", "lucky bamboo hydroponic", .easy, "Spiral green cane stems rise from a tall clear vase with submerged white roots.", ["Hydroponic", "Beginner Friendly", "Low Light"]),
        ("hydro-pothos", "Hydro Pothos", "Epipremnum aureum", "pothos hydroponic", .easy, "Golden-variegated heart-shaped leaves trail from a glass jar with dense white roots in water.", ["Hydroponic", "Easy Roots", "Beginner Friendly"]),
        ("hydro-spider", "Hydro Spider Plant", "Chlorophytum comosum", "spider plant hydroponic", .easy, "Striped arching leaves and hanging spiderettes above a glass bowl of visible white roots.", ["Hydroponic", "Beginner Friendly", "Root Display"]),
        ("hydro-syngonium", "Hydro Arrowhead", "Syngonium podophyllum", "syngonium hydroponic", .easy, "Cream-and-green arrow-shaped leaves root in a clear vase with pebbles and submerged roots.", ["Hydroponic", "Easy Care", "Decorative"]),
        ("hydro-philodendron", "Hydro Philodendron", "Philodendron hederaceum", "philodendron hydroponic", .easy, "Glossy heart-shaped leaves trail from a wall-mounted glass tube with roots in water.", ["Hydroponic", "Beginner Friendly", "Vining"]),
        ("hydro-tradescantia", "Hydro Inch Plant", "Tradescantia zebrina", "tradescantia hydroponic", .easy, "Metallic purple-and-silver striped stems root rapidly in clear test-tube propagation containers.", ["Hydroponic", "Fast Roots", "Colorful"]),
        ("hydro-coleus", "Hydro Coleus", "Coleus scutellarioides", "coleus hydroponic", .easy, "Magenta, lime, and burgundy variegated leaves grow in a glass cylinder with pink-white roots in water.", ["Hydroponic", "Color Foliage", "Beginner Friendly"]),
        ("hydro-aglaonema", "Hydro Chinese Evergreen", "Aglaonema modestum", "aglaonema hydroponic", .medium, "Silver-patterned lance leaves in a semi-hydro LECA pebble setup with a visible water reservoir.", ["Hydroponic", "Low Light", "Moderate Care"]),
        ("hydro-ivy", "Hydro English Ivy", "Hedera helix", "ivy hydroponic", .medium, "Deeply lobed ivy leaves cascade from a wall-mounted glass vessel with roots visible in water.", ["Hydroponic", "Vining", "Moderate Care"]),
        ("hydro-mint", "Hydro Mint", "Mentha spicata", "mint hydroponic", .easy, "Serrated bright-green mint stems root in a clear mason jar on a sunny kitchen windowsill.", ["Hydroponic", "Edible", "Beginner Friendly"])
    ]

    private static let herbSeeds: [PlantSeed] = [
        ("herb-basil", "Sweet Basil", "Ocimum basilicum", "basil herb", .easy, "A kitchen essential with fast leafy growth in warm light.", ["Edible", "Beginner Friendly", "Kitchen"]),
        ("herb-mint", "Spearmint", "Mentha spicata", "spearmint herb", .easy, "Refreshing aromatic herb with vigorous regrowth after harvest.", ["Edible", "Fast Grower", "Beginner Friendly"]),
        ("herb-rosemary", "Rosemary", "Salvia rosmarinus", "rosemary herb", .medium, "Woody aromatic herb that prefers sun and dry intervals.", ["Edible", "Aromatic", "Sun Lover"]),
        ("herb-thyme", "Thyme", "Thymus vulgaris", "thyme herb", .easy, "Compact savory herb with strong flavor and easy care.", ["Edible", "Compact", "Beginner Friendly"]),
        ("herb-oregano", "Oregano", "Origanum vulgare", "oregano herb", .easy, "Mediterranean herb with robust flavor and drought tolerance.", ["Edible", "Aromatic", "Drought Tolerant"]),
        ("herb-parsley", "Parsley", "Petroselinum crispum", "parsley herb", .medium, "Fresh garnish herb that prefers consistent moisture.", ["Edible", "Kitchen", "Moderate Care"]),
        ("herb-chives", "Chives", "Allium schoenoprasum", "chives herb", .easy, "Easy cut-and-come-again herb for regular use.", ["Edible", "Beginner Friendly", "Frequent Harvest"]),
        ("herb-lemongrass", "Lemongrass", "Cymbopogon citratus", "lemongrass herb", .medium, "Citrus-scented stalk herb for warm bright spots.", ["Edible", "Aromatic", "Sun Lover"]),
        ("herb-cilantro", "Cilantro", "Coriandrum sativum", "cilantro herb", .medium, "Quick-cycle herb best in mild temperatures and bright light.", ["Edible", "Fast Cycle", "Kitchen"]),
        ("herb-sage", "Sage", "Salvia officinalis", "sage herb", .medium, "Soft textured aromatic herb that prefers dry intervals.", ["Edible", "Aromatic", "Moderate Care"])
    ]
}
