import Foundation

struct TokenResponse: Codable {
    let token: String?
    let error: String?
    let errorcode: String?
}

struct SiteInfo: Codable {
    let userid: Int
    let fullname: String
    let sitename: String
}

struct MoodleCourse: Codable {
    let id: Int
    let fullname: String
    let shortname: String
}

struct AssignmentsResponse: Codable {
    let courses: [AssignmentCourse]
}

struct AssignmentCourse: Codable {
    let id: Int
    let fullname: String
    let assignments: [Assignment]
}

struct Assignment: Codable {
    let id: Int
    let name: String
    let intro: String?
    let duedate: Int
    let cmid: Int?
}

struct MoodleError: Codable {
    let exception: String?
    let errorcode: String?
    let message: String?
}

struct ICalEvent {
    let uid: String
    let summary: String
    let description: String?
    let dtstart: Date?
    let dtend: Date?
    let categories: String?
}
