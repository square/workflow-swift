/*
 * Copyright 2017 Square Inc.
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
package com.squareup.sample.tictactoe

import com.squareup.viewbuilder.StackScreen
import com.squareup.workflow.Renderer
import com.squareup.workflow.WorkflowInput
import com.squareup.workflow.WorkflowPool

object TakeTurnsRenderer : Renderer<Turn, TakeTurnsEvent, StackScreen<GamePlayScreen>> {
  override fun render(
    state: Turn,
    workflow: WorkflowInput<TakeTurnsEvent>,
    workflows: WorkflowPool
  ): StackScreen<GamePlayScreen> = StackScreen(GamePlayScreen(state, workflow::sendEvent))
}