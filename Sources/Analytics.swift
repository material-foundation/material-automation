/*
 Copyright 2018 the Material Automation authors. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 https://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation
import PerfectCURL
import PerfectLogger

class Analytics {
  static let googleAnalyticsAPI = "http://www.google-analytics.com/collect"

  class func trackEvent(category: String, action: String, label: String = "0", value: String = "0") {
    guard let GATrackingID = ProcessInfo.processInfo.environment["GA_TRACKING_ID"] else {
      return
    }
    let data: [String: String] =
      ["v": "1",
       "tid": GATrackingID,
       "cid": "1",
       "t": "event",
       "ec": category,
       "ea": action,
       "el": label,
       "ev": value]

    let body = "\(data.map { return "\($0.0.stringByEncodingURL)=\($0.1.stringByEncodingURL)" }.joined(separator: "&"))"
    do {
      let response = try CURLRequest(googleAnalyticsAPI, .postString(body)).perform()
      LogFile.debug(response.bodyString)
    } catch {
      LogFile.error("error: \(error) desc: \(error.localizedDescription)")
    }
  }
}
