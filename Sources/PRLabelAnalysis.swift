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

import PerfectLib
import Foundation
import PerfectLogger
import PerfectCURL

class PRLabelAnalysis {

  class func getTitleLabel(title: String) -> String? {
    do {
      let regex = try NSRegularExpression(pattern: "\\[(.*?)\\]", options: [])
      let nsString = NSString(string: title)

      let results = regex.matches(in: title,
                                  options: [], range: NSMakeRange(0, nsString.length))
      guard let range = results.first?.range else {
        return nil
      }
      return nsString.substring(with: range)
    } catch let error as NSError {
      LogFile.error("invalid regex: \(error.localizedDescription)")
    } catch {
      LogFile.error("\(error)")
    }
    return nil
  }

  class func getFilePaths(url: String) -> [String] {
    var paths = [String]()
    do {
      let contents =
        try CURLRequest(url, .followLocation(true)).perform().bodyString
      print(contents)
      let lines = contents.split(separator: "\n")
      for line in lines {
        if line.starts(with: "+++") {
          let lowerIndex = line.index(line.startIndex, offsetBy: 6)
          let substring = line.substring(with: Range(uncheckedBounds: (lower: lowerIndex,
                                                                       upper: line.endIndex)))
          paths.append(substring)
        }
      }
    } catch {
      LogFile.error("\(error)")
    }
    return paths
  }

  class func grabLabelsFromPaths(paths: [String]) -> [String] {
    var labels = [String]()
    for path in paths {
      if path.starts(with: "components/") {
        let slashed = path.split(separator: "/")
        labels.append("[\(slashed[1])]")
      } else if path.starts(with: "catalog/") {
        labels.append("[Catalog]")
      }
    }
    return labels
  }

}
