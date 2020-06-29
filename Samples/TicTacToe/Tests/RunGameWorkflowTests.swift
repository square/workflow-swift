/*
 * Copyright 2020 Square Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import AlertContainer
import Workflow
import WorkflowTesting
import XCTest

@testable import Development_SampleTicTacToe

class RunGameWorkflowTests: XCTestCase {
    // MARK: Action Tests

    func test_action_updatePlayers() {
        let initalState = RunGameWorkflow.State(playerX: "X", playerO: "O", step: .newGame)

        RunGameWorkflow
            .Action
            .tester(withState: initalState)
            .send(
                action: .updatePlayerX("❌"),
                outputAssertions: { output in
                    XCTAssertNil(output)
                }
            )
            .assertState { state in
                XCTAssertEqual(state.playerX, "❌")
                XCTAssertEqual(state.playerO, "O")
                XCTAssertEqual(state.step, .newGame)
            }.send(
                action: .updatePlayerO("🅾️"),
                outputAssertions: { output in
                    XCTAssertNil(output)
                }
            )
            .assertState { state in
                XCTAssertEqual(state.playerX, "❌")
                XCTAssertEqual(state.playerO, "🅾️")
                XCTAssertEqual(state.step, .newGame)
            }
    }

    func test_action_startGame() {
        let initalState = RunGameWorkflow.State(
            playerX: "X",
            playerO: "O",
            step: .newGame
        )

        RunGameWorkflow
            .Action
            .tester(withState: initalState)
            .send(
                action: .startGame,
                outputAssertions: { output in
                    XCTAssertNil(output)
                }
            )
            .assertState { state in
                XCTAssertEqual(state.playerX, "X")
                XCTAssertEqual(state.playerO, "O")
                XCTAssertEqual(state.step, .playing)
            }
    }

    func test_action_back() {
        let playingState = RunGameWorkflow.State(
            playerX: "X",
            playerO: "O",
            step: .playing
        )

        RunGameWorkflow
            .Action
            .tester(withState: playingState)
            .send(
                action: .back,
                outputAssertions: { output in
                    XCTAssertNil(output)
                }
            )
            .assertState { state in
                XCTAssertEqual(state.playerX, "X")
                XCTAssertEqual(state.playerO, "O")
                XCTAssertEqual(state.step, .newGame)
            }
    }

    func test_action_confirmQuit() {
        let playingState = RunGameWorkflow.State(
            playerX: "X",
            playerO: "O",
            step: .playing
        )

        RunGameWorkflow
            .Action
            .tester(withState: playingState)
            .send(
                action: .confirmQuit,
                outputAssertions: { output in
                    XCTAssertNil(output)
                }
            )
            .assertState { state in
                XCTAssertEqual(state.playerX, "X")
                XCTAssertEqual(state.playerO, "O")
                XCTAssertEqual(state.step, .maybeQuit)
            }
    }

    // MARK: Render Tests

    func test_render_newGame() {
        RunGameWorkflow()
            .renderTester(
                initialState: RunGameWorkflow.State(
                    playerX: "X",
                    playerO: "O",
                    step: .newGame
                )
            )
            .render { screen in
            }
            .assertNoAction()
    }

    func test_render_playing() {
        RunGameWorkflow()
            .renderTester(
                initialState: RunGameWorkflow.State(
                    playerX: "X",
                    playerO: "O",
                    step: .playing
                )
            )
            .expectWorkflow(
                type: TakeTurnsWorkflow.self,
                producingRendering: TakeTurnsWorkflow.Rendering(
                    gameState: .tie,
                    playerX: "",
                    playerO: "",
                    board: [],
                    onSelected: { _, _ in }
                )
            )
            .render { screen in
                XCTAssertNil(screen.alert)
            }
            .assertNoAction()
    }

    func test_render_maybeQuit() {
        RunGameWorkflow()
            .renderTester(
                initialState: RunGameWorkflow.State(
                    playerX: "X",
                    playerO: "O",
                    step: .maybeQuit
                )
            )
            .expectWorkflow(
                type: ConfirmQuitWorkflow.self,
                producingRendering: (
                    ConfirmQuitScreen(question: ""),
                    Alert(title: "title", message: "message", actions: [])
                )
            )
            .expectWorkflow(
                type: TakeTurnsWorkflow.self,
                producingRendering: TakeTurnsWorkflow.Rendering(
                    gameState: .tie,
                    playerX: "",
                    playerO: "",
                    board: [],
                    onSelected: { _, _ in }
                )
            )
            .render { screen in
                XCTAssertNotNil(screen.alert)
                XCTAssertEqual(screen.alert!.title, "title")
                XCTAssertEqual(screen.alert!.message, "message")
                XCTAssertEqual(screen.baseScreen.modals.count, 1)
            }
            .assertNoAction()
    }
}
