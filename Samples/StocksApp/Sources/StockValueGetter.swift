//
//  StockValueGetter.swift
//  Development-StocksApp
//
//  Created by Dhaval Shreyas on 10/14/20.
//

import Foundation

struct StockValueWorkflow {
    func get() {
        URLSession
            .shared
            .dataTask(with: URL(string: "https://finnhub.io/api/v1/quote?symbol=AAPL")!) { data, response, error in
                guard let data = data else {
                    return
                }

                let response = try? JSONDecoder().decode(FinnResponse.self, from: data)
                print(response?.c)
            }.resume()
    }
}

struct FinnResponse: Codable {
    let c: Double?
}
