//
//  FakeNetworkManager.swift
//  AsyncWorker
//
//  Created by Mark Johnson on 6/16/22.
//

import Foundation

class FakeNetworkManager {
    static var requestCount = 0
    static func makeFakeNetworkRequest() -> FakeRequest {
        requestCount += 1
        return FakeRequest(requestNumber: requestCount)
    }
}

class FakeRequest {
    enum FakeRequestError: Error {
        case cancelled
    }
    
    let requestNumber: Int
    
    init(requestNumber: Int) {
        self.requestNumber = requestNumber
    }
    

    var cancelled: Bool = false

    func cancel() {
        cancelled = true
    }

    func perform(completion: @escaping (Result<Model, Error>) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(1)) {
            guard !self.cancelled else {
                completion(.failure(FakeRequestError.cancelled))
                return
            }

            completion(.success(Model(message: "Request \(self.requestNumber) Successful!")))
        }
    }
}
