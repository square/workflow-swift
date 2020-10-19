//
//  StockValueGetter.swift
//  Development-StocksApp
//
//  Created by Dhaval Shreyas on 10/14/20.
//

import Foundation
import Workflow

struct StockValueWorkflow: Workflow {
    typealias State = Double?
    typealias Rendering = Double?
    typealias Output = Never

    func makeInitialState() -> Double? {
        nil
    }

    func render(state: Double?,
                context: RenderContext<StockValueWorkflow>) -> Double? {
        let sink = context.makeSink(of: AnyWorkflowAction.self)
            .contraMap { (value: Double?) in
                AnyWorkflowAction { state in
                    state = value
                    return nil
                }
            }

        context.runSideEffect(key: "") { lifetime in
            let task = URLSession
                .shared
                .dataTask(with: URL(string: "https://finnhub.io/api/v1/quote?symbol=AAPL")!) { data, response, error in
                    guard let data = data else {
                        return
                    }

                    let response = try? JSONDecoder().decode(FinnResponse.self, from: data)

                    DispatchQueue.main.async {
                        sink.send(response?.c)
                    }
                }

            task.resume()

            lifetime.onEnded {
                task.cancel()
            }
        }
        return state
    }

    func get() {}
}

struct FinnResponse: Codable {
    let c: Double?
}
