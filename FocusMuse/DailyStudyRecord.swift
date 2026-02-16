import Foundation
import SwiftData

@Model
final class DailyStudyRecord {
    var date: Date
    var studySeconds: Int
    var breakSeconds: Int

    init(date: Date, studySeconds: Int, breakSeconds: Int = 0) {
        self.date = date
        self.studySeconds = studySeconds
        self.breakSeconds = breakSeconds
    }
}
