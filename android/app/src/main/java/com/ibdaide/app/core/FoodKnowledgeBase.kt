package com.ibdaide.app.core

/**
 * Built-in IBD food-safety knowledge base (offline). Same content as iOS.
 *
 * Sources:
 * - CCF: Crohn's & Colitis Foundation, "What Should I Eat?"
 *   https://www.crohnscolitisfoundation.org/patientsandcaregivers/diet-and-nutrition/what-should-i-eat
 * - IOIBD: Dietary Guidance for Patients With IBD (Levine et al., 2020)
 *   https://www.cghjournal.org/article/S1542-3565(20)30185-3/fulltext
 *
 * Informational only — tolerance is individual; not medical advice.
 */

enum class Verdict(val label: String) { GREEN("Looks OK"), CAUTION("Caution"), AVOID("Avoid") }

enum class KBSource(val label: String, val url: String) {
    CCF("Crohn's & Colitis Foundation",
        "https://www.crohnscolitisfoundation.org/patientsandcaregivers/diet-and-nutrition/what-should-i-eat"),
    IOIBD("IOIBD 2020 guidance",
        "https://www.cghjournal.org/article/S1542-3565(20)30185-3/fulltext"),
    APP("IBD Aide heuristic", ""),
}

data class KBIngredientRule(
    val name: String, val keywords: List<String>, val reason: String,
    val source: KBSource, val remission: Verdict, val flare: Verdict,
)

data class KBSafeFood(val name: String, val keywords: List<String>, val note: String, val source: KBSource)

data class KBDish(val name: String, val aliases: List<String>, val typicalIngredients: List<String>, val note: String)

object FoodKnowledgeBase {

    val rules: List<KBIngredientRule> = listOf(
        // ---- IOIBD 2020: food additives ----
        KBIngredientRule("Carrageenan", listOf("carrageenan"),
            "IOIBD advises reducing carrageenan (thickener linked to gut inflammation), especially in Crohn's",
            KBSource.IOIBD, Verdict.CAUTION, Verdict.AVOID),
        KBIngredientRule("Carboxymethylcellulose", listOf("carboxymethylcellulose", "cellulose gum", "cmc"),
            "IOIBD advises reducing this emulsifier; associated with gut-barrier disruption",
            KBSource.IOIBD, Verdict.CAUTION, Verdict.AVOID),
        KBIngredientRule("Polysorbate-80", listOf("polysorbate 80", "polysorbate-80", "polysorbate"),
            "IOIBD advises reducing this emulsifier; associated with gut-barrier disruption",
            KBSource.IOIBD, Verdict.CAUTION, Verdict.AVOID),
        KBIngredientRule("Maltodextrin", listOf("maltodextrin"),
            "IOIBD advises limiting maltodextrin, particularly in ulcerative colitis",
            KBSource.IOIBD, Verdict.CAUTION, Verdict.CAUTION),
        KBIngredientRule("Artificial sweeteners", listOf("aspartame", "sucralose", "saccharin", "acesulfame"),
            "IOIBD advises limiting artificial sweeteners, particularly in ulcerative colitis",
            KBSource.IOIBD, Verdict.CAUTION, Verdict.CAUTION),
        KBIngredientRule("Titanium dioxide", listOf("titanium dioxide", "e171"),
            "IOIBD advises reducing titanium dioxide (nanoparticle additive)",
            KBSource.IOIBD, Verdict.CAUTION, Verdict.CAUTION),
        KBIngredientRule("Sulfites", listOf("sulfite", "sulphite", "sulfur dioxide", "sulphur dioxide"),
            "IOIBD advises reducing sulfur-compound additives",
            KBSource.IOIBD, Verdict.CAUTION, Verdict.CAUTION),
        KBIngredientRule("Gums / thickeners", listOf("xanthan gum", "guar gum", "gellan gum", "locust bean gum"),
            "IOIBD flags thickening agents as prudent to limit in processed foods",
            KBSource.IOIBD, Verdict.GREEN, Verdict.CAUTION),
        KBIngredientRule("Trans fats", listOf("partially hydrogenated", "trans fat", "hydrogenated oil"),
            "IOIBD advises reducing trans/hydrogenated fats in all IBD",
            KBSource.IOIBD, Verdict.AVOID, Verdict.AVOID),
        KBIngredientRule("Processed meat", listOf("bacon", "sausage", "salami", "pepperoni", "hot dog", "ham", "prosciutto", "chorizo", "deli meat", "bologna"),
            "IOIBD advises reducing processed meat, especially in ulcerative colitis",
            KBSource.IOIBD, Verdict.CAUTION, Verdict.AVOID),
        KBIngredientRule("Red meat", listOf("beef", "steak", "pork", "lamb", "ground beef", "veal"),
            "IOIBD advises reducing red meat in ulcerative colitis; moderate portions if tolerated",
            KBSource.IOIBD, Verdict.GREEN, Verdict.CAUTION),

        // ---- CCF: common flare triggers ----
        KBIngredientRule("Whole nuts", listOf("almonds", "walnuts", "pecans", "peanuts", "cashews", "pistachios", "mixed nuts", "hazelnuts"),
            "CCF: whole nuts are high-insoluble-fiber and hard to digest during flares (smooth nut butters are usually fine)",
            KBSource.CCF, Verdict.GREEN, Verdict.CAUTION),
        KBIngredientRule("Seeds", listOf("sunflower seeds", "sesame seeds", "chia", "flaxseed", "flax seed", "pumpkin seeds", "poppy seed"),
            "CCF: whole seeds are a common flare trigger (insoluble fiber)",
            KBSource.CCF, Verdict.GREEN, Verdict.CAUTION),
        KBIngredientRule("Popcorn", listOf("popcorn"),
            "CCF: popcorn is high-residue roughage — a classic flare trigger",
            KBSource.CCF, Verdict.GREEN, Verdict.AVOID),
        KBIngredientRule("Whole grains / bran", listOf("bran", "whole wheat", "whole grain", "brown rice", "rye", "quinoa", "barley"),
            "CCF: whole grains add insoluble fiber; switch to refined grains during flares",
            KBSource.CCF, Verdict.GREEN, Verdict.CAUTION),
        KBIngredientRule("Corn", listOf("corn", "cornmeal", "corn on the cob", "tortilla"),
            "CCF: corn is hard to digest and a common trigger during flares",
            KBSource.CCF, Verdict.GREEN, Verdict.CAUTION),
        KBIngredientRule("Raw cruciferous vegetables", listOf("broccoli", "cauliflower", "cabbage", "kale", "brussels sprouts", "coleslaw"),
            "CCF: gas-producing cruciferous vegetables often aggravate flares (well-cooked may be tolerated)",
            KBSource.CCF, Verdict.GREEN, Verdict.CAUTION),
        KBIngredientRule("Raw vegetables / salad", listOf("raw vegetables", "lettuce", "salad", "raw onion", "celery"),
            "CCF: raw produce with skins/stalks is high-residue; cooked and peeled is gentler during flares",
            KBSource.CCF, Verdict.GREEN, Verdict.CAUTION),
        KBIngredientRule("Beans & legumes", listOf("beans", "black beans", "kidney beans", "chickpea", "lentil", "refried beans", "hummus"),
            "CCF: legumes are gas-producing and high-fiber — common flare trigger",
            KBSource.CCF, Verdict.GREEN, Verdict.CAUTION),
        KBIngredientRule("Dried fruit / prunes", listOf("dried fruit", "prune", "raisin", "dried apricot", "fig"),
            "CCF: dried fruits are concentrated fiber/sugars with laxative effect",
            KBSource.CCF, Verdict.CAUTION, Verdict.AVOID),
        KBIngredientRule("Fruit skins", listOf("apple with skin", "unpeeled", "grape", "berries", "raspberry", "blackberry"),
            "CCF: skins and seedy fruits add insoluble fiber; peel fruit during flares",
            KBSource.CCF, Verdict.GREEN, Verdict.CAUTION),
        KBIngredientRule("Lactose (high-lactose dairy)", listOf("milk", "whole milk", "cream", "heavy cream", "ice cream", "soft cheese", "sour cream", "condensed milk", "milkshake", "cheese", "mozzarella", "queso", "paneer", "ricotta", "cream cheese"),
            "CCF: high-lactose dairy is a frequent trigger; lactose-free or hard aged cheeses are usually better tolerated",
            KBSource.CCF, Verdict.CAUTION, Verdict.CAUTION),
        KBIngredientRule("Butter / high-fat dairy", listOf("butter", "ghee"),
            "CCF: high-fat foods can worsen symptoms, especially with fat malabsorption",
            KBSource.CCF, Verdict.GREEN, Verdict.CAUTION),
        KBIngredientRule("Fried / greasy", listOf("fried", "deep-fried", "deep fried", "lard", "shortening", "battered", "tempura", "crispy"),
            "CCF: greasy and fried foods commonly trigger cramping and diarrhea",
            KBSource.CCF, Verdict.CAUTION, Verdict.AVOID),
        KBIngredientRule("Spicy", listOf("spicy", "chili", "chilli", "cayenne", "hot sauce", "jalapeno", "jalapeño", "sriracha", "gochujang", "wasabi", "curry powder", "harissa", "buffalo sauce"),
            "CCF: spicy foods are among the most common symptom triggers",
            KBSource.CCF, Verdict.CAUTION, Verdict.AVOID),
        KBIngredientRule("Caffeine", listOf("coffee", "espresso", "energy drink", "caffeine", "cola", "black tea", "matcha", "guarana"),
            "CCF: caffeine stimulates the bowel and can worsen diarrhea",
            KBSource.CCF, Verdict.GREEN, Verdict.CAUTION),
        KBIngredientRule("Chocolate / cocoa", listOf("chocolate", "cocoa"),
            "CCF: chocolate is a commonly reported trigger (caffeine + fat + sugar)",
            KBSource.CCF, Verdict.GREEN, Verdict.CAUTION),
        KBIngredientRule("Alcohol", listOf("alcohol", "beer", "wine", "rum", "vodka", "whiskey", "tequila", "sake"),
            "CCF: alcohol commonly worsens symptoms and can interact with IBD medications",
            KBSource.CCF, Verdict.CAUTION, Verdict.AVOID),
        KBIngredientRule("Carbonated drinks", listOf("carbonated", "soda", "sparkling", "seltzer"),
            "CCF: carbonation causes gas and bloating",
            KBSource.CCF, Verdict.GREEN, Verdict.CAUTION),
        KBIngredientRule("Sugar alcohols", listOf("sorbitol", "mannitol", "xylitol", "maltitol", "erythritol", "isomalt", "sugar-free"),
            "CCF: sugar alcohols in sugar-free products have a laxative effect",
            KBSource.CCF, Verdict.CAUTION, Verdict.AVOID),
        KBIngredientRule("High-fructose corn syrup", listOf("high-fructose corn syrup", "high fructose corn syrup", "hfcs"),
            "CCF: concentrated fructose can worsen diarrhea and gas",
            KBSource.CCF, Verdict.CAUTION, Verdict.CAUTION),
        KBIngredientRule("Added sugar (heavy)", listOf("candy", "frosting", "syrup"),
            "CCF: sugary foods can draw water into the gut and worsen diarrhea",
            KBSource.CCF, Verdict.GREEN, Verdict.CAUTION),
        KBIngredientRule("Garlic & onion", listOf("garlic", "onion"),
            "Common fermentable (FODMAP) triggers for gas and cramping in many IBD patients",
            KBSource.APP, Verdict.GREEN, Verdict.CAUTION),
        KBIngredientRule("Inulin / chicory fiber", listOf("inulin", "chicory root", "chicory fiber"),
            "Added fermentable fiber commonly causes bloating and cramping",
            KBSource.APP, Verdict.CAUTION, Verdict.AVOID),
    )

    val safeFoods: List<KBSafeFood> = listOf(
        KBSafeFood("White rice", listOf("white rice", "rice", "jasmine rice", "basmati"), "Refined grain — a CCF flare staple", KBSource.CCF),
        KBSafeFood("White bread / refined pasta", listOf("white bread", "pasta", "noodles", "sourdough", "bagel", "cream of wheat"), "Refined grains are gentler during flares", KBSource.CCF),
        KBSafeFood("Oatmeal", listOf("oatmeal", "oats", "porridge"), "Soluble fiber — usually well tolerated", KBSource.CCF),
        KBSafeFood("Banana", listOf("banana"), "Low-fiber fruit — well tolerated", KBSource.CCF),
        KBSafeFood("Melon", listOf("melon", "cantaloupe", "honeydew", "watermelon"), "Low-fiber fruit — well tolerated", KBSource.CCF),
        KBSafeFood("Applesauce / peeled cooked fruit", listOf("applesauce", "peeled apple", "canned peaches"), "Peeled and cooked fruit is gentle", KBSource.CCF),
        KBSafeFood("Peeled cooked vegetables", listOf("cooked carrots", "zucchini", "squash", "green beans", "asparagus tips", "peeled potato", "mashed potato", "sweet potato"), "Cooked, peeled, seedless vegetables are gentler", KBSource.CCF),
        KBSafeFood("Eggs", listOf("egg", "eggs", "omelette", "scrambled egg"), "Well-tolerated lean protein", KBSource.CCF),
        KBSafeFood("Poultry", listOf("chicken", "chicken breast", "turkey", "grilled chicken"), "Lean protein — recommended (grilled/baked, not fried)", KBSource.CCF),
        KBSafeFood("Fish", listOf("fish", "salmon", "tuna", "cod", "tilapia", "white fish"), "Lean protein with omega-3s — recommended", KBSource.CCF),
        KBSafeFood("Tofu", listOf("tofu"), "Well-tolerated plant protein", KBSource.CCF),
        KBSafeFood("Smooth nut butter", listOf("peanut butter", "almond butter", "smooth nut butter"), "Smooth (not chunky) nut butters are usually fine", KBSource.CCF),
        KBSafeFood("Lactose-free / fermented dairy", listOf("lactose-free", "lactose free", "kefir", "greek yogurt", "yogurt", "parmesan", "aged cheddar", "swiss cheese", "feta"), "Lactose-free and hard aged dairy are usually better tolerated", KBSource.CCF),
        KBSafeFood("Broth / clear soup", listOf("broth", "bone broth", "consomme", "clear soup"), "Hydrating and gentle during flares", KBSource.CCF),
        KBSafeFood("Herbal tea / water", listOf("herbal tea", "chamomile", "peppermint tea", "water"), "Caffeine-free hydration", KBSource.CCF),
        KBSafeFood("Avocado (ripe)", listOf("avocado"), "Soft, nutrient-dense; usually tolerated in moderation", KBSource.CCF),
    )

    val dishes: List<KBDish> = listOf(
        KBDish("Pizza", listOf("pizza", "pepperoni pizza"), listOf("white bread", "cheese", "tomato", "pepperoni", "oil"), "Cheese + processed meat; greasy varieties are harder during flares"),
        KBDish("Cheeseburger", listOf("hamburger", "burger", "cheeseburger"), listOf("beef", "white bread", "cheese", "fried", "onion"), "Red meat + fried elements"),
        KBDish("French fries", listOf("french fries", "fries", "chips"), listOf("potato", "fried", "oil"), "Deep-fried"),
        KBDish("Fried chicken", listOf("fried chicken", "chicken nuggets", "chicken tenders", "karaage"), listOf("chicken", "fried", "battered", "oil"), "Deep-fried; grilled chicken is the gentler swap"),
        KBDish("Hot dog", listOf("hot dog", "corn dog"), listOf("hot dog", "white bread", "onion"), "Processed meat"),
        KBDish("Tacos", listOf("taco", "tacos"), listOf("corn", "beef", "cheese", "chili", "onion", "lettuce"), "Corn shell + spice + cheese"),
        KBDish("Burrito", listOf("burrito", "burrito bowl"), listOf("beans", "rice", "cheese", "beef", "chili", "sour cream"), "Beans and cheese are the usual culprits"),
        KBDish("Nachos", listOf("nachos"), listOf("corn", "cheese", "jalapeno", "beans", "fried"), "Fried corn + spice + cheese"),
        KBDish("Quesadilla", listOf("quesadilla"), listOf("cheese", "tortilla", "butter"), "High-lactose"),
        KBDish("Chili", listOf("chili con carne", "chili"), listOf("beans", "beef", "chili", "onion", "tomato"), "Legumes + spice"),
        KBDish("Curry", listOf("curry", "tikka masala", "vindaloo", "madras", "thai curry", "korma"), listOf("curry powder", "chili", "cream", "onion", "garlic"), "Spice + cream; milder kormas may be gentler"),
        KBDish("Biryani", listOf("biryani", "fried rice", "pilaf"), listOf("rice", "spicy", "onion", "oil"), "Spiced rice; plain rice is the gentle swap"),
        KBDish("Samosa / pakora", listOf("samosa", "pakora", "spring roll", "egg roll"), listOf("fried", "potato", "onion", "spicy"), "Deep-fried"),
        KBDish("Dal", listOf("dal", "daal", "lentil soup"), listOf("lentil", "onion", "garlic", "spicy"), "Legumes + spice; small portions if tolerated"),
        KBDish("Ramen", listOf("ramen", "noodle soup"), listOf("noodles", "broth", "egg", "chili", "garlic"), "Broth + noodles are gentle; watch chili oil and fatty pork"),
        KBDish("Pho", listOf("pho"), listOf("broth", "noodles", "beef", "herbs"), "Clear broth base is flare-friendly; skip sriracha and raw garnish"),
        KBDish("Sushi", listOf("sushi", "sashimi", "california roll"), listOf("white rice", "fish", "seaweed", "wasabi"), "Rice + fish are gentle; skip wasabi, tempura and spicy mayo rolls"),
        KBDish("Pad thai", listOf("pad thai"), listOf("noodles", "peanuts", "egg", "chili", "fried"), "Peanuts + chili; ask for mild"),
        KBDish("Lasagna", listOf("lasagna", "lasagne"), listOf("pasta", "cheese", "beef", "tomato", "ricotta"), "Heavy dairy + red meat"),
        KBDish("Spaghetti", listOf("spaghetti", "pasta", "bolognese", "carbonara"), listOf("pasta", "tomato", "beef", "cream", "garlic", "cheese"), "Plain pasta is gentle; creamy/meaty sauces less so"),
        KBDish("Mac & cheese", listOf("macaroni", "mac and cheese"), listOf("pasta", "cheese", "butter", "milk"), "High-lactose"),
        KBDish("Grilled cheese", listOf("grilled cheese"), listOf("white bread", "cheese", "butter"), "High-lactose + butter"),
        KBDish("Caesar salad", listOf("caesar salad", "salad", "garden salad"), listOf("lettuce", "raw vegetables", "cheese", "dressing"), "Raw greens are a flare trigger; cooked vegetables are gentler"),
        KBDish("Coleslaw", listOf("coleslaw"), listOf("cabbage", "raw vegetables", "cream"), "Raw cruciferous + creamy dressing"),
        KBDish("Steak", listOf("steak", "ribeye", "sirloin"), listOf("beef", "butter"), "Red meat — IOIBD advises moderation, especially in UC"),
        KBDish("BBQ ribs", listOf("ribs", "barbecue", "bbq", "pulled pork"), listOf("pork", "syrup", "spicy"), "Red meat + sugary spicy sauce"),
        KBDish("Bacon & eggs", listOf("bacon", "full breakfast", "breakfast plate"), listOf("bacon", "egg", "butter", "fried"), "Processed meat; plain eggs alone are well tolerated"),
        KBDish("Fish and chips", listOf("fish and chips"), listOf("fish", "battered", "fried", "potato"), "The fish is good — the deep-fry batter isn't; baked fish is the swap"),
        KBDish("Grilled salmon", listOf("grilled salmon", "salmon", "baked fish"), listOf("salmon"), "CCF-recommended lean protein"),
        KBDish("Grilled chicken", listOf("grilled chicken", "roast chicken", "rotisserie chicken", "chicken breast"), listOf("grilled chicken"), "CCF-recommended lean protein"),
        KBDish("Chicken noodle soup", listOf("chicken noodle soup", "chicken soup", "soup"), listOf("broth", "chicken", "noodles", "cooked carrots"), "Classic flare-friendly meal"),
        KBDish("Tomato soup", listOf("tomato soup"), listOf("tomato", "cream", "broth"), "Acidity + cream bother some people"),
        KBDish("Clam chowder", listOf("clam chowder", "chowder"), listOf("cream", "potato", "bacon"), "Heavy cream base"),
        KBDish("Omelette", listOf("omelette", "omelet", "scrambled eggs", "eggs"), listOf("egg", "butter", "cheese"), "Eggs are well tolerated; go light on cheese"),
        KBDish("Pancakes / waffles", listOf("pancake", "pancakes", "waffle", "french toast"), listOf("white bread", "butter", "syrup"), "Refined flour is fine; heavy syrup and butter add up"),
        KBDish("Oatmeal bowl", listOf("oatmeal", "porridge", "congee"), listOf("oatmeal", "banana"), "Flare-friendly; skip added nuts and dried fruit"),
        KBDish("Granola / trail mix", listOf("granola", "trail mix", "muesli"), listOf("oats", "almonds", "seeds", "dried fruit", "honey"), "Nuts, seeds and dried fruit — high-residue"),
        KBDish("Sandwich / deli sub", listOf("sandwich", "sub", "blt", "club sandwich", "panini"), listOf("white bread", "deli meat", "cheese", "lettuce"), "Processed deli meat is the main flag; turkey on white is gentler"),
        KBDish("Falafel / shawarma", listOf("falafel", "shawarma", "gyro", "kebab", "doner"), listOf("chickpea", "fried", "garlic", "lamb", "spicy"), "Fried legumes / spiced meats"),
        KBDish("Hummus plate", listOf("hummus"), listOf("chickpea", "garlic", "sesame seeds"), "Legume-based; small portions if tolerated"),
        KBDish("Dumplings", listOf("dumpling", "dumplings", "gyoza", "potsticker"), listOf("pork", "wheat", "fried", "garlic"), "Steamed are gentler than fried"),
        KBDish("Chow mein / stir-fry", listOf("chow mein", "stir fry", "lo mein", "teriyaki"), listOf("noodles", "oil", "garlic", "onion", "soy sauce"), "Oil + allium heavy; steamed dishes are gentler"),
        KBDish("Tempura / katsu", listOf("tempura", "katsu", "tonkatsu"), listOf("fried", "battered", "pork"), "Deep-fried"),
        KBDish("Bibimbap", listOf("bibimbap"), listOf("rice", "egg", "gochujang", "raw vegetables"), "Rice + egg are gentle; gochujang is spicy"),
        KBDish("Kimchi", listOf("kimchi"), listOf("cabbage", "chili", "garlic"), "Spicy fermented cruciferous"),
        KBDish("Buffalo wings", listOf("chicken wings", "wings", "buffalo wings"), listOf("chicken", "fried", "buffalo sauce", "butter"), "Fried + hot sauce"),
        KBDish("Onion rings", listOf("onion rings"), listOf("onion", "battered", "fried"), "Fried allium"),
        KBDish("Ice cream", listOf("ice cream", "sundae", "gelato", "frozen yogurt"), listOf("ice cream", "cream", "chocolate"), "High lactose + fat + sugar; lactose-free versions exist"),
        KBDish("Milkshake / smoothie", listOf("milkshake", "smoothie"), listOf("milk", "ice cream", "banana"), "Dairy-based; a banana + lactose-free yogurt smoothie is gentler"),
        KBDish("Donut / pastry", listOf("doughnut", "donut", "croissant", "danish", "muffin"), listOf("fried", "sugar", "butter", "white bread"), "Fried dough + sugar"),
        KBDish("Cake / brownie", listOf("cake", "brownie", "cupcake", "cookie"), listOf("sugar", "butter", "chocolate", "white bread"), "Rich desserts add fat + sugar; small portions"),
        KBDish("Popcorn (snack)", listOf("popcorn"), listOf("popcorn", "butter"), "Classic high-residue trigger"),
        KBDish("Guacamole & chips", listOf("guacamole"), listOf("avocado", "corn", "fried", "onion", "jalapeno"), "Avocado is fine — the fried corn chips and raw onion aren't"),
        KBDish("Baked potato", listOf("baked potato", "mashed potatoes", "potato"), listOf("peeled potato", "butter", "sour cream"), "Peeled potato is flare-friendly; go light on toppings"),
        KBDish("Rice bowl", listOf("rice bowl", "white rice", "steamed rice"), listOf("white rice"), "Flare-friendly staple"),
        KBDish("Yogurt parfait", listOf("yogurt", "parfait"), listOf("greek yogurt", "granola", "berries"), "Yogurt is usually fine; granola and seedy berries are the flags"),
        KBDish("Espresso / coffee drink", listOf("coffee", "espresso", "latte", "cappuccino"), listOf("coffee", "milk"), "Caffeine + milk"),
        KBDish("Beer / cocktail", listOf("beer", "wine", "cocktail", "margarita"), listOf("alcohol", "carbonated"), "Alcohol is a CCF-listed trigger"),
    )

    // MARK: Lookup

    sealed class LookupResult {
        data class Dish(val dish: KBDish, val eval: FoodEvaluation) : LookupResult()
        data class Ingredient(val rule: KBIngredientRule) : LookupResult()
        data class Safe(val food: KBSafeFood) : LookupResult()
    }

    fun search(term: String, personalTriggers: List<String>, flareMode: Boolean): List<LookupResult> {
        val q = term.lowercase().trim()
        if (q.length < 2) return emptyList()
        val results = mutableListOf<LookupResult>()
        dishes.filter { d -> d.name.lowercase().contains(q) || d.aliases.any { it.contains(q) || q.contains(it) } }
            .forEach { d ->
                val eval = FoodRulesEngine.evaluate(d.typicalIngredients.joinToString(", "), personalTriggers, flareMode)
                results += LookupResult.Dish(d, eval)
            }
        rules.filter { r -> r.name.lowercase().contains(q) || r.keywords.any { it.contains(q) || q.contains(it) } }
            .forEach { results += LookupResult.Ingredient(it) }
        safeFoods.filter { s -> s.name.lowercase().contains(q) || s.keywords.any { it.contains(q) || q.contains(it) } }
            .forEach { results += LookupResult.Safe(it) }
        return results.take(12)
    }

    fun dishForLabels(labels: List<String>): KBDish? {
        val lowered = labels.map { it.lowercase() }
        for (label in lowered) {
            dishes.firstOrNull { d -> d.aliases.any { label.contains(it) || it.contains(label) } }?.let { return it }
        }
        return null
    }
}
