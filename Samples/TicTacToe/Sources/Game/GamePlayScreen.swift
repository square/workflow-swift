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

import UIKit
import WorkflowUI

struct GamePlayScreen: Screen {
    var gameState: GameState
    var playerX: String
    var playerO: String
    var board: [[Board.Cell]]
    var onSelected: (Int, Int) -> Void

    func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        GamePlayViewController.description(for: self, environment: environment)
    }
}

final class GamePlayViewController: ScreenViewController<GamePlayScreen> {
    let titleLabel: UILabel = .init(frame: .zero)
    let cells: [[UIButton]] = (0 ..< 3).map { _ in
        (0 ..< 3).map { _ in UIButton(frame: .zero) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 32.0)
        view.addSubview(titleLabel)

        var toggle = true
        for row in cells {
            for cell in row {
                let backgroundColor = if toggle {
                    UIColor(white: 0.92, alpha: 1.0)
                } else {
                    UIColor(white: 0.82, alpha: 1.0)
                }
                cell.backgroundColor = backgroundColor
                toggle = !toggle

                cell.titleLabel?.font = UIFont.boldSystemFont(ofSize: 66.0)
                cell.addTarget(self, action: #selector(buttonPressed(sender:)), for: .touchUpInside)
                view.addSubview(cell)
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let inset: CGFloat = 8.0
        let boardLength = min(view.bounds.width, view.bounds.height) - inset * 2
        let cellLength = boardLength / 3.0

        let bounds = view.bounds.inset(by: view.safeAreaInsets)
        titleLabel.frame = CGRect(
            x: bounds.origin.x,
            y: bounds.origin.y,
            width: bounds.size.width,
            height: 44.0
        )

        var yOffset = (view.bounds.height - boardLength) / 2.0
        for row in cells {
            var xOffset = inset
            for cell in row {
                cell.frame = CGRect(
                    x: xOffset,
                    y: yOffset,
                    width: cellLength,
                    height: cellLength
                )

                xOffset += inset + cellLength
            }
            yOffset += inset + cellLength
        }
    }

    override func screenDidChange(from previousScreen: GamePlayScreen, previousEnvironment: ViewEnvironment) {
        super.screenDidChange(from: previousScreen, previousEnvironment: previousEnvironment)

        let title = switch screen.gameState {
        case .ongoing(turn: let turn):
            switch turn {
            case .x:
                "\(screen.playerX), place your 🙅"
            case .o:
                "\(screen.playerO), place your 🙆"
            }

        case .tie:
            "It's a Tie!"

        case .win(let player):
            switch player {
            case .x:
                "The 🙅's have it, \(screen.playerX) wins!"
            case .o:
                "The 🙆's have it, \(screen.playerO) wins!"
            }
        }
        titleLabel.text = title

        for row in 0 ..< 3 {
            let cols = screen.board[row]
            for col in 0 ..< 3 {
                switch cols[col] {
                case .empty:
                    cells[row][col].setTitle("", for: .normal)
                case .taken(let player):
                    switch player {
                    case .x:
                        cells[row][col].setTitle("🙅", for: .normal)
                    case .o:
                        cells[row][col].setTitle("🙆", for: .normal)
                    }
                }
            }
        }
    }

    @objc private func buttonPressed(sender: UIButton) {
        for row in 0 ..< 3 {
            let cols = cells[row]
            for col in 0 ..< 3 {
                if cols[col] == sender {
                    screen.onSelected(row, col)
                    return
                }
            }
        }
    }
}
