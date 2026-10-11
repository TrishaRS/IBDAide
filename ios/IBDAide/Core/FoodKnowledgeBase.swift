import Foundation

/// Built-in IBD food-safety knowledge base (ships inside the app — works offline).
///
/// Compiled from authoritative guidance:
/// - CCF: Crohn's & Colitis Foundation, "What Should I Eat?"
///   https://www.crohnscolitisfoundation.org/patientsandcaregivers/diet-and-nutrition/what-should-i-eat
/// - IOIBD: International Organization for the Study of IBD, "Dietary Guidance for
///   Patients With IBD" (Levine et al., Clin Gastroenterol Hepatol 2020)
///   https://www.cghjournal.org/article/S1542-3565(20)30185-3/fulltext
///
/// Informational only — tolerance is individual; not medical advice.

enum KBSource: String {
    case ccf = "Crohn's & Colitis Foundation"
    case ioibd = "IOIBD 2020 guidance"
    case app = "IBD Aide heuristic"
    case nutritionist = "Your nutritionist"

    var url: String {
        switch self {
        case .ccf: return "https://www.crohnscolitisfoundation.org/patientsandcaregivers/diet-and-nutrition/what-should-i-eat"
        case .ioibd: return "https://www.cghjournal.org/article/S1542-3565(20)30185-3/fulltext"
        case .app, .nutritionist: return ""
        }
    }
}

struct KBIngredientRule {
    let name: String
    let keywords: [String]
    let reason: String
    let source: KBSource
    let remission: Verdict
    let flare: Verdict
}

struct KBSafeFood {
    let name: String
    let keywords: [String]
    let note: String
    let source: KBSource
}

struct KBDish {
    let name: String
    let aliases: [String]          // match against classifier labels / user search
    let typicalIngredients: [String]
    let note: String
}

enum FoodKnowledgeBase {

    // MARK: - Ingredient / component rules (flagged)

    static let rules: [KBIngredientRule] = [
        // ---- IOIBD 2020: food additives ----
        .init(name: "Carrageenan", keywords: ["carrageenan"],
              reason: "IOIBD advises reducing carrageenan (thickener linked to gut inflammation), especially in Crohn's",
              source: .ioibd, remission: .caution, flare: .avoid),
        .init(name: "Carboxymethylcellulose", keywords: ["carboxymethylcellulose", "cellulose gum", "cmc"],
              reason: "IOIBD advises reducing this emulsifier; associated with gut-barrier disruption",
              source: .ioibd, remission: .caution, flare: .avoid),
        .init(name: "Polysorbate-80", keywords: ["polysorbate 80", "polysorbate-80", "polysorbate"],
              reason: "IOIBD advises reducing this emulsifier; associated with gut-barrier disruption",
              source: .ioibd, remission: .caution, flare: .avoid),
        .init(name: "Maltodextrin", keywords: ["maltodextrin"],
              reason: "IOIBD advises limiting maltodextrin, particularly in ulcerative colitis",
              source: .ioibd, remission: .caution, flare: .caution),
        .init(name: "Artificial sweeteners", keywords: ["aspartame", "sucralose", "saccharin", "acesulfame"],
              reason: "IOIBD advises limiting artificial sweeteners, particularly in ulcerative colitis",
              source: .ioibd, remission: .caution, flare: .caution),
        .init(name: "Titanium dioxide", keywords: ["titanium dioxide", "e171"],
              reason: "IOIBD advises reducing titanium dioxide (nanoparticle additive)",
              source: .ioibd, remission: .caution, flare: .caution),
        .init(name: "Sulfites", keywords: ["sulfite", "sulphite", "sulfur dioxide", "sulphur dioxide"],
              reason: "IOIBD advises reducing sulfur-compound additives",
              source: .ioibd, remission: .caution, flare: .caution),
        .init(name: "Gums / thickeners", keywords: ["xanthan gum", "guar gum", "gellan gum", "locust bean gum"],
              reason: "IOIBD flags thickening agents as prudent to limit in processed foods",
              source: .ioibd, remission: .green, flare: .caution),
        .init(name: "Trans fats", keywords: ["partially hydrogenated", "trans fat", "hydrogenated oil"],
              reason: "IOIBD advises reducing trans/hydrogenated fats in all IBD",
              source: .ioibd, remission: .avoid, flare: .avoid),
        .init(name: "Processed meat", keywords: ["bacon", "sausage", "salami", "pepperoni", "hot dog", "ham", "prosciutto", "chorizo", "deli meat", "bologna"],
              reason: "IOIBD advises reducing processed meat, especially in ulcerative colitis",
              source: .ioibd, remission: .caution, flare: .avoid),
        .init(name: "Red meat", keywords: ["beef", "steak", "pork", "lamb", "ground beef", "veal"],
              reason: "IOIBD advises reducing red meat in ulcerative colitis; moderate portions if tolerated",
              source: .ioibd, remission: .green, flare: .caution),

        // ---- CCF: common flare triggers ----
        .init(name: "Whole nuts", keywords: ["almonds", "walnuts", "pecans", "peanuts", "cashews", "pistachios", "mixed nuts", "hazelnuts"],
              reason: "CCF: whole nuts are high-insoluble-fiber and hard to digest during flares (smooth nut butters are usually fine)",
              source: .ccf, remission: .green, flare: .caution),
        .init(name: "Seeds", keywords: ["sunflower seeds", "sesame seeds", "chia", "flaxseed", "flax seed", "pumpkin seeds", "poppy seed"],
              reason: "CCF: whole seeds are a common flare trigger (insoluble fiber)",
              source: .ccf, remission: .green, flare: .caution),
        .init(name: "Popcorn", keywords: ["popcorn"],
              reason: "CCF: popcorn is high-residue roughage — a classic flare trigger",
              source: .ccf, remission: .green, flare: .avoid),
        .init(name: "Whole grains / bran", keywords: ["bran", "whole wheat", "whole grain", "brown rice", "rye", "quinoa", "barley"],
              reason: "CCF: whole grains add insoluble fiber; switch to refined grains during flares",
              source: .ccf, remission: .green, flare: .caution),
        .init(name: "Corn", keywords: ["corn", "cornmeal", "corn on the cob", "tortilla"],
              reason: "CCF: corn is hard to digest and a common trigger during flares",
              source: .ccf, remission: .green, flare: .caution),
        .init(name: "Raw cruciferous vegetables", keywords: ["broccoli", "cauliflower", "cabbage", "kale", "brussels sprouts", "coleslaw"],
              reason: "CCF: gas-producing cruciferous vegetables often aggravate flares (well-cooked may be tolerated)",
              source: .ccf, remission: .green, flare: .caution),
        .init(name: "Raw vegetables / salad", keywords: ["raw vegetables", "lettuce", "salad", "raw onion", "celery"],
              reason: "CCF: raw produce with skins/stalks is high-residue; cooked and peeled is gentler during flares",
              source: .ccf, remission: .green, flare: .caution),
        .init(name: "Beans & legumes", keywords: ["beans", "black beans", "kidney beans", "chickpea", "lentil", "refried beans", "hummus"],
              reason: "CCF: legumes are gas-producing and high-fiber — common flare trigger",
              source: .ccf, remission: .green, flare: .caution),
        .init(name: "Dried fruit / prunes", keywords: ["dried fruit", "prune", "raisin", "dried apricot", "fig"],
              reason: "CCF: dried fruits are concentrated fiber/sugars with laxative effect",
              source: .ccf, remission: .caution, flare: .avoid),
        .init(name: "Fruit skins", keywords: ["apple with skin", "unpeeled", "grape", "berries", "raspberry", "blackberry"],
              reason: "CCF: skins and seedy fruits add insoluble fiber; peel fruit during flares",
              source: .ccf, remission: .green, flare: .caution),
        .init(name: "Lactose (high-lactose dairy)", keywords: ["milk", "whole milk", "cream", "heavy cream", "ice cream", "soft cheese", "sour cream", "condensed milk", "milkshake", "cheese", "mozzarella", "queso", "paneer", "ricotta", "cream cheese"],
              reason: "CCF: high-lactose dairy is a frequent trigger; lactose-free or hard aged cheeses are usually better tolerated",
              source: .ccf, remission: .caution, flare: .caution),
        .init(name: "Butter / high-fat dairy", keywords: ["butter", "ghee"],
              reason: "CCF: high-fat foods can worsen symptoms, especially with fat malabsorption",
              source: .ccf, remission: .green, flare: .caution),
        .init(name: "Fried / greasy", keywords: ["fried", "deep-fried", "deep fried", "lard", "shortening", "battered", "tempura", "crispy"],
              reason: "CCF: greasy and fried foods commonly trigger cramping and diarrhea",
              source: .ccf, remission: .caution, flare: .avoid),
        .init(name: "Spicy", keywords: ["spicy", "chili", "chilli", "cayenne", "hot sauce", "jalapeno", "jalapeño", "sriracha", "gochujang", "wasabi", "curry powder", "harissa", "buffalo sauce"],
              reason: "CCF: spicy foods are among the most common symptom triggers",
              source: .ccf, remission: .caution, flare: .avoid),
        .init(name: "Caffeine", keywords: ["coffee", "espresso", "energy drink", "caffeine", "cola", "black tea", "matcha", "guarana"],
              reason: "CCF: caffeine stimulates the bowel and can worsen diarrhea",
              source: .ccf, remission: .green, flare: .caution),
        .init(name: "Chocolate / cocoa", keywords: ["chocolate", "cocoa"],
              reason: "CCF: chocolate is a commonly reported trigger (caffeine + fat + sugar)",
              source: .ccf, remission: .green, flare: .caution),
        .init(name: "Alcohol", keywords: ["alcohol", "beer", "wine", "rum", "vodka", "whiskey", "tequila", "sake"],
              reason: "CCF: alcohol commonly worsens symptoms and can interact with IBD medications",
              source: .ccf, remission: .caution, flare: .avoid),
        .init(name: "Carbonated drinks", keywords: ["carbonated", "soda", "sparkling", "seltzer"],
              reason: "CCF: carbonation causes gas and bloating",
              source: .ccf, remission: .green, flare: .caution),
        .init(name: "Sugar alcohols", keywords: ["sorbitol", "mannitol", "xylitol", "maltitol", "erythritol", "isomalt", "sugar-free"],
              reason: "CCF: sugar alcohols in sugar-free products have a laxative effect",
              source: .ccf, remission: .caution, flare: .avoid),
        .init(name: "High-fructose corn syrup", keywords: ["high-fructose corn syrup", "high fructose corn syrup", "hfcs"],
              reason: "CCF: concentrated fructose can worsen diarrhea and gas",
              source: .ccf, remission: .caution, flare: .caution),
        .init(name: "Added sugar (heavy)", keywords: ["candy", "frosting", "syrup"],
              reason: "CCF: sugary foods can draw water into the gut and worsen diarrhea",
              source: .ccf, remission: .green, flare: .caution),
        .init(name: "Garlic & onion", keywords: ["garlic", "onion"],
              reason: "Common fermentable (FODMAP) triggers for gas and cramping in many IBD patients",
              source: .app, remission: .green, flare: .caution),
        .init(name: "Inulin / chicory fiber", keywords: ["inulin", "chicory root", "chicory fiber"],
              reason: "Added fermentable fiber commonly causes bloating and cramping",
              source: .app, remission: .caution, flare: .avoid),
    ]

    // MARK: - Generally well-tolerated foods (CCF flare-friendly list)

    static let safeFoods: [KBSafeFood] = [
        .init(name: "White rice", keywords: ["white rice", "rice", "jasmine rice", "basmati"], note: "Refined grain — a CCF flare staple", source: .ccf),
        .init(name: "White bread / refined pasta", keywords: ["white bread", "pasta", "noodles", "sourdough", "bagel", "cream of wheat"], note: "Refined grains are gentler during flares", source: .ccf),
        .init(name: "Oatmeal", keywords: ["oatmeal", "oats", "porridge"], note: "Soluble fiber — usually well tolerated", source: .ccf),
        .init(name: "Banana", keywords: ["banana"], note: "Low-fiber fruit — well tolerated", source: .ccf),
        .init(name: "Melon", keywords: ["melon", "cantaloupe", "honeydew", "watermelon"], note: "Low-fiber fruit — well tolerated", source: .ccf),
        .init(name: "Applesauce / peeled cooked fruit", keywords: ["applesauce", "peeled apple", "canned peaches"], note: "Peeled and cooked fruit is gentle", source: .ccf),
        .init(name: "Peeled cooked vegetables", keywords: ["cooked carrots", "zucchini", "squash", "green beans", "asparagus tips", "peeled potato", "mashed potato", "sweet potato"], note: "Cooked, peeled, seedless vegetables are gentler", source: .ccf),
        .init(name: "Eggs", keywords: ["egg", "eggs", "omelette", "scrambled egg"], note: "Well-tolerated lean protein", source: .ccf),
        .init(name: "Poultry", keywords: ["chicken", "chicken breast", "turkey", "grilled chicken"], note: "Lean protein — recommended (grilled/baked, not fried)", source: .ccf),
        .init(name: "Fish", keywords: ["fish", "salmon", "tuna", "cod", "tilapia", "white fish"], note: "Lean protein with omega-3s — recommended", source: .ccf),
        .init(name: "Tofu", keywords: ["tofu"], note: "Well-tolerated plant protein", source: .ccf),
        .init(name: "Smooth nut butter", keywords: ["peanut butter", "almond butter", "smooth nut butter"], note: "Smooth (not chunky) nut butters are usually fine", source: .ccf),
        .init(name: "Lactose-free / fermented dairy", keywords: ["lactose-free", "lactose free", "kefir", "greek yogurt", "yogurt", "parmesan", "aged cheddar", "swiss cheese", "feta"], note: "Lactose-free and hard aged dairy are usually better tolerated", source: .ccf),
        .init(name: "Broth / clear soup", keywords: ["broth", "bone broth", "consomme", "clear soup"], note: "Hydrating and gentle during flares", source: .ccf),
        .init(name: "Herbal tea / water", keywords: ["herbal tea", "chamomile", "peppermint tea", "water"], note: "Caffeine-free hydration", source: .ccf),
        .init(name: "Avocado (ripe)", keywords: ["avocado"], note: "Soft, nutrient-dense; usually tolerated in moderation", source: .ccf),
    ]

    // MARK: - Dish inventory (matches camera classifier labels & lookup terms)

    static let dishes: [KBDish] = [
        KBDish(name: "Pizza", aliases: ["pizza", "pepperoni pizza"], typicalIngredients: ["white bread", "cheese", "tomato", "pepperoni", "oil"], note: "Cheese + processed meat; greasy varieties are harder during flares"),
        KBDish(name: "Cheeseburger", aliases: ["hamburger", "burger", "cheeseburger"], typicalIngredients: ["beef", "white bread", "cheese", "fried", "onion"], note: "Red meat + fried elements"),
        KBDish(name: "French fries", aliases: ["french fries", "fries", "chips"], typicalIngredients: ["potato", "fried", "oil"], note: "Deep-fried"),
        KBDish(name: "Fried chicken", aliases: ["fried chicken", "chicken nuggets", "chicken tenders", "karaage"], typicalIngredients: ["chicken", "fried", "battered", "oil"], note: "Deep-fried; grilled chicken is the gentler swap"),
        KBDish(name: "Hot dog", aliases: ["hot dog", "corn dog"], typicalIngredients: ["hot dog", "white bread", "onion"], note: "Processed meat"),
        KBDish(name: "Tacos", aliases: ["taco", "tacos"], typicalIngredients: ["corn", "beef", "cheese", "chili", "onion", "lettuce"], note: "Corn shell + spice + cheese"),
        KBDish(name: "Burrito", aliases: ["burrito", "burrito bowl"], typicalIngredients: ["beans", "rice", "cheese", "beef", "chili", "sour cream"], note: "Beans and cheese are the usual culprits"),
        KBDish(name: "Nachos", aliases: ["nachos"], typicalIngredients: ["corn", "cheese", "jalapeno", "beans", "fried"], note: "Fried corn + spice + cheese"),
        KBDish(name: "Quesadilla", aliases: ["quesadilla"], typicalIngredients: ["cheese", "tortilla", "butter"], note: "High-lactose"),
        KBDish(name: "Chili", aliases: ["chili con carne", "chili"], typicalIngredients: ["beans", "beef", "chili", "onion", "tomato"], note: "Legumes + spice"),
        KBDish(name: "Curry", aliases: ["curry", "tikka masala", "vindaloo", "madras", "thai curry", "korma"], typicalIngredients: ["curry powder", "chili", "cream", "onion", "garlic"], note: "Spice + cream; milder kormas may be gentler"),
        KBDish(name: "Biryani", aliases: ["biryani", "fried rice", "pilaf"], typicalIngredients: ["rice", "spicy", "onion", "oil"], note: "Spiced rice; plain rice is the gentle swap"),
        KBDish(name: "Samosa / pakora", aliases: ["samosa", "pakora", "spring roll", "egg roll"], typicalIngredients: ["fried", "potato", "onion", "spicy"], note: "Deep-fried"),
        KBDish(name: "Dal", aliases: ["dal", "daal", "lentil soup"], typicalIngredients: ["lentil", "onion", "garlic", "spicy"], note: "Legumes + spice; small portions if tolerated"),
        KBDish(name: "Ramen", aliases: ["ramen", "noodle soup"], typicalIngredients: ["noodles", "broth", "egg", "chili", "garlic"], note: "Broth + noodles are gentle; watch chili oil and fatty pork"),
        KBDish(name: "Pho", aliases: ["pho"], typicalIngredients: ["broth", "noodles", "beef", "herbs"], note: "Clear broth base is flare-friendly; skip sriracha and raw garnish"),
        KBDish(name: "Sushi", aliases: ["sushi", "sashimi", "california roll"], typicalIngredients: ["white rice", "fish", "seaweed", "wasabi"], note: "Rice + fish are gentle; skip wasabi, tempura and spicy mayo rolls"),
        KBDish(name: "Pad thai", aliases: ["pad thai"], typicalIngredients: ["noodles", "peanuts", "egg", "chili", "fried"], note: "Peanuts + chili; ask for mild"),
        KBDish(name: "Lasagna", aliases: ["lasagna", "lasagne"], typicalIngredients: ["pasta", "cheese", "beef", "tomato", "ricotta"], note: "Heavy dairy + red meat"),
        KBDish(name: "Spaghetti", aliases: ["spaghetti", "pasta", "bolognese", "carbonara"], typicalIngredients: ["pasta", "tomato", "beef", "cream", "garlic", "cheese"], note: "Plain pasta is gentle; creamy/meaty sauces less so"),
        KBDish(name: "Mac & cheese", aliases: ["macaroni", "mac and cheese"], typicalIngredients: ["pasta", "cheese", "butter", "milk"], note: "High-lactose"),
        KBDish(name: "Grilled cheese", aliases: ["grilled cheese"], typicalIngredients: ["white bread", "cheese", "butter"], note: "High-lactose + butter"),
        KBDish(name: "Caesar salad", aliases: ["caesar salad", "salad", "garden salad"], typicalIngredients: ["lettuce", "raw vegetables", "cheese", "dressing"], note: "Raw greens are a flare trigger; cooked vegetables are gentler"),
        KBDish(name: "Coleslaw", aliases: ["coleslaw"], typicalIngredients: ["cabbage", "raw vegetables", "cream"], note: "Raw cruciferous + creamy dressing"),
        KBDish(name: "Steak", aliases: ["steak", "ribeye", "sirloin"], typicalIngredients: ["beef", "butter"], note: "Red meat — IOIBD advises moderation, especially in UC"),
        KBDish(name: "BBQ ribs", aliases: ["ribs", "barbecue", "bbq", "pulled pork"], typicalIngredients: ["pork", "syrup", "spicy"], note: "Red meat + sugary spicy sauce"),
        KBDish(name: "Bacon & eggs", aliases: ["bacon", "full breakfast", "breakfast plate"], typicalIngredients: ["bacon", "egg", "butter", "fried"], note: "Processed meat; plain eggs alone are well tolerated"),
        KBDish(name: "Fish and chips", aliases: ["fish and chips"], typicalIngredients: ["fish", "battered", "fried", "potato"], note: "The fish is good — the deep-fry batter isn't; baked fish is the swap"),
        KBDish(name: "Grilled salmon", aliases: ["grilled salmon", "salmon", "baked fish"], typicalIngredients: ["salmon"], note: "CCF-recommended lean protein"),
        KBDish(name: "Grilled chicken", aliases: ["grilled chicken", "roast chicken", "rotisserie chicken", "chicken breast"], typicalIngredients: ["grilled chicken"], note: "CCF-recommended lean protein"),
        KBDish(name: "Chicken noodle soup", aliases: ["chicken noodle soup", "chicken soup", "soup"], typicalIngredients: ["broth", "chicken", "noodles", "cooked carrots"], note: "Classic flare-friendly meal"),
        KBDish(name: "Tomato soup", aliases: ["tomato soup"], typicalIngredients: ["tomato", "cream", "broth"], note: "Acidity + cream bother some people"),
        KBDish(name: "Clam chowder", aliases: ["clam chowder", "chowder"], typicalIngredients: ["cream", "potato", "bacon"], note: "Heavy cream base"),
        KBDish(name: "Omelette", aliases: ["omelette", "omelet", "scrambled eggs", "eggs"], typicalIngredients: ["egg", "butter", "cheese"], note: "Eggs are well tolerated; go light on cheese"),
        KBDish(name: "Pancakes / waffles", aliases: ["pancake", "pancakes", "waffle", "french toast"], typicalIngredients: ["white bread", "butter", "syrup"], note: "Refined flour is fine; heavy syrup and butter add up"),
        KBDish(name: "Oatmeal bowl", aliases: ["oatmeal", "porridge", "congee"], typicalIngredients: ["oatmeal", "banana"], note: "Flare-friendly; skip added nuts and dried fruit"),
        KBDish(name: "Granola / trail mix", aliases: ["granola", "trail mix", "muesli"], typicalIngredients: ["oats", "almonds", "seeds", "dried fruit", "honey"], note: "Nuts, seeds and dried fruit — high-residue"),
        KBDish(name: "Sandwich / deli sub", aliases: ["sandwich", "sub", "blt", "club sandwich", "panini"], typicalIngredients: ["white bread", "deli meat", "cheese", "lettuce"], note: "Processed deli meat is the main flag; turkey on white is gentler"),
        KBDish(name: "Falafel / shawarma", aliases: ["falafel", "shawarma", "gyro", "kebab", "doner"], typicalIngredients: ["chickpea", "fried", "garlic", "lamb", "spicy"], note: "Fried legumes / spiced meats"),
        KBDish(name: "Hummus plate", aliases: ["hummus"], typicalIngredients: ["chickpea", "garlic", "sesame seeds"], note: "Legume-based; small portions if tolerated"),
        KBDish(name: "Dumplings", aliases: ["dumpling", "dumplings", "gyoza", "potsticker"], typicalIngredients: ["pork", "wheat", "fried", "garlic"], note: "Steamed are gentler than fried"),
        KBDish(name: "Chow mein / stir-fry", aliases: ["chow mein", "stir fry", "lo mein", "teriyaki"], typicalIngredients: ["noodles", "oil", "garlic", "onion", "soy sauce"], note: "Oil + allium heavy; steamed dishes are gentler"),
        KBDish(name: "Tempura / katsu", aliases: ["tempura", "katsu", "tonkatsu"], typicalIngredients: ["fried", "battered", "pork"], note: "Deep-fried"),
        KBDish(name: "Bibimbap", aliases: ["bibimbap"], typicalIngredients: ["rice", "egg", "gochujang", "raw vegetables"], note: "Rice + egg are gentle; gochujang is spicy"),
        KBDish(name: "Kimchi", aliases: ["kimchi"], typicalIngredients: ["cabbage", "chili", "garlic"], note: "Spicy fermented cruciferous"),
        KBDish(name: "Buffalo wings", aliases: ["chicken wings", "wings", "buffalo wings"], typicalIngredients: ["chicken", "fried", "buffalo sauce", "butter"], note: "Fried + hot sauce"),
        KBDish(name: "Onion rings", aliases: ["onion rings"], typicalIngredients: ["onion", "battered", "fried"], note: "Fried allium"),
        KBDish(name: "Ice cream", aliases: ["ice cream", "sundae", "gelato", "frozen yogurt"], typicalIngredients: ["ice cream", "cream", "chocolate"], note: "High lactose + fat + sugar; lactose-free versions exist"),
        KBDish(name: "Milkshake / smoothie", aliases: ["milkshake", "smoothie"], typicalIngredients: ["milk", "ice cream", "banana"], note: "Dairy-based; a banana + lactose-free yogurt smoothie is gentler"),
        KBDish(name: "Donut / pastry", aliases: ["doughnut", "donut", "croissant", "danish", "muffin"], typicalIngredients: ["fried", "sugar", "butter", "white bread"], note: "Fried dough + sugar"),
        KBDish(name: "Cake / brownie", aliases: ["cake", "brownie", "cupcake", "cookie"], typicalIngredients: ["sugar", "butter", "chocolate", "white bread"], note: "Rich desserts add fat + sugar; small portions"),
        KBDish(name: "Popcorn (snack)", aliases: ["popcorn"], typicalIngredients: ["popcorn", "butter"], note: "Classic high-residue trigger"),
        KBDish(name: "Guacamole & chips", aliases: ["guacamole"], typicalIngredients: ["avocado", "corn", "fried", "onion", "jalapeno"], note: "Avocado is fine — the fried corn chips and raw onion aren't"),
        KBDish(name: "Baked potato", aliases: ["baked potato", "mashed potatoes", "potato"], typicalIngredients: ["peeled potato", "butter", "sour cream"], note: "Peeled potato is flare-friendly; go light on toppings"),
        KBDish(name: "Rice bowl", aliases: ["rice bowl", "white rice", "steamed rice"], typicalIngredients: ["white rice"], note: "Flare-friendly staple"),
        KBDish(name: "Yogurt parfait", aliases: ["yogurt", "parfait"], typicalIngredients: ["greek yogurt", "granola", "berries"], note: "Yogurt is usually fine; granola and seedy berries are the flags"),
        KBDish(name: "Espresso / coffee drink", aliases: ["coffee", "espresso", "latte", "cappuccino"], typicalIngredients: ["coffee", "milk"], note: "Caffeine + milk"),
        KBDish(name: "Beer / cocktail", aliases: ["beer", "wine", "cocktail", "margarita"], typicalIngredients: ["alcohol", "carbonated"], note: "Alcohol is a CCF-listed trigger"),
    ]

    // MARK: - Lookup

    enum LookupResult {
        case dish(KBDish, FoodEvaluation)
        case ingredient(KBIngredientRule)
        case safe(KBSafeFood)
    }

    /// Search the knowledge base for a free-text term (dish name, food, or ingredient).
    static func search(_ term: String, personalTriggers: [String], flareMode: Bool) -> [LookupResult] {
        let q = term.lowercased().trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [] }
        var results: [LookupResult] = []

        for dish in dishes where dish.name.lowercased().contains(q) || dish.aliases.contains(where: { $0.contains(q) || q.contains($0) }) {
            let eval = FoodRulesEngine.evaluate(ingredientsText: dish.typicalIngredients.joined(separator: ", "),
                                                personalTriggers: personalTriggers, flareMode: flareMode)
            results.append(.dish(dish, eval))
        }
        for rule in rules where rule.name.lowercased().contains(q) || rule.keywords.contains(where: { $0.contains(q) || q.contains($0) }) {
            results.append(.ingredient(rule))
        }
        for safe in safeFoods where safe.name.lowercased().contains(q) || safe.keywords.contains(where: { $0.contains(q) || q.contains($0) }) {
            results.append(.safe(safe))
        }
        return Array(results.prefix(12))
    }

    /// Best dish match for camera classifier labels.
    static func dish(forLabels labels: [String]) -> KBDish? {
        let lowered = labels.map { $0.lowercased() }
        for label in lowered {
            if let hit = dishes.first(where: { d in d.aliases.contains(where: { label.contains($0) || $0.contains(label) }) }) {
                return hit
            }
        }
        return nil
    }
}
