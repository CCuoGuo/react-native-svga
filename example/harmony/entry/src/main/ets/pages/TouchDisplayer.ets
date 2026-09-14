/**
 * MIT License
 *
 * Copyright (C) 2026 Huawei Device Co., Ltd.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */


@Component
export struct TouchDisplayer {
  @State currentTouches: TouchObject[] = []
  @State touchIndicatorOpacity: number = 0
  @BuilderParam buildChildren: () => void
  build() {
    Stack() {
      this.buildChildren()
      ForEach(this.currentTouches, (activeTouch: TouchObject) => {
        Stack() {
        }
        .width(64)
        .height(64)
        .backgroundColor("blue")
        .borderWidth(2)
        .borderColor("white")
        .opacity(this.touchIndicatorOpacity)
        .position({ x: activeTouch.x - 32, y: activeTouch.y - 32 })
        .borderRadius(1000)
        .hitTestBehavior(HitTestMode.Transparent)
      })
    }
    .width("100%")
    .height("100%")
    .hitTestBehavior(HitTestMode.Transparent)
    .onTouch(e => {
      this.currentTouches = e.touches
      this.touchIndicatorOpacity = 0.5
      animateTo({
        duration: 500,
        curve: Curve.Linear,
      }, () => {
        this.touchIndicatorOpacity = 0
      })
    })
  }
}