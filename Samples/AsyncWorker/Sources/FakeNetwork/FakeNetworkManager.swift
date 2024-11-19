//
//  FakeNetworkManager.swift
//  AsyncWorker
//
//  Created by Mark Johnson on 6/16/22.
//

import Foundation

class FakeNetworkManager {
    static func makeFakeNetworkRequest() -> FakeRequest {
        FakeRequest()
    }
}

class FakeRequest {
    enum FakeRequestError: Error {
        case cancelled
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

            completion(.success(Model(message: "Request Successful!")))
        }
    }
}
