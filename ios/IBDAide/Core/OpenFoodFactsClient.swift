import Foundation

/// Fetches product info from Open Food Facts. The ONLY data sent is the barcode
/// digits — never any user or health data (NFR-2).
struct OFFProduct {
    let barcode: String
    let name: String
    let brand: String
    let ingredientsText: String
}

enum OFFError: LocalizedError {
    case notFound, badResponse
    var errorDescription: String? {
        switch self {
        case .notFound: return "Product not found in Open Food Facts. Try photographing the ingredient label instead."
        case .badResponse: return "Couldn't reach the food database. Check your connection or scan the label photo."
        }
    }
}

enum OpenFoodFactsClient {

    /// Search products by name (user-typed term only — never health data).
    static func search(name: String) async throws -> [OFFProduct] {
        let q = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        guard let url = URL(string: "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(q)&search_simple=1&action=process&json=1&page_size=10&fields=code,product_name,brands,ingredients_text") else {
            throw OFFError.badResponse
        }
        var request = URLRequest(url: url)
        request.setValue("IBDAide/1.0 (iOS; contact: reachritesh@gmail.com)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw OFFError.badResponse }

        struct SearchEnvelope: Decodable {
            struct P: Decodable {
                let code: String?
                let product_name: String?
                let brands: String?
                let ingredients_text: String?
            }
            let products: [P]?
        }
        let env = try JSONDecoder().decode(SearchEnvelope.self, from: data)
        return (env.products ?? [])
            .filter { !($0.ingredients_text ?? "").isEmpty }
            .map { OFFProduct(barcode: $0.code ?? "", name: $0.product_name ?? "Unknown product",
                              brand: $0.brands ?? "", ingredientsText: $0.ingredients_text ?? "") }
    }

    static func fetch(barcode: String) async throws -> OFFProduct {
        let clean = barcode.filter(\.isNumber)
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(clean)?fields=product_name,brands,ingredients_text") else {
            throw OFFError.badResponse
        }
        var request = URLRequest(url: url)
        request.setValue("IBDAide/1.0 (iOS; contact: reachritesh@gmail.com)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw OFFError.badResponse }

        struct Envelope: Decodable {
            struct P: Decodable {
                let product_name: String?
                let brands: String?
                let ingredients_text: String?
            }
            let status: Int?
            let product: P?
        }
        let env = try JSONDecoder().decode(Envelope.self, from: data)
        guard env.status == 1, let p = env.product else { throw OFFError.notFound }
        return OFFProduct(barcode: clean,
                          name: p.product_name ?? "Unknown product",
                          brand: p.brands ?? "",
                          ingredientsText: p.ingredients_text ?? "")
    }
}
