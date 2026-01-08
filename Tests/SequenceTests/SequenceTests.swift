import XCTest
@testable import Sequence

final class SequenceTests: XCTestCase {
    
    func testConfiguration() async throws {
        let kit = Sequence.shared

        // Should throw if not configured
        do {
            _ = try await kit.fetchConfig()
            XCTFail("Should have thrown notConfigured error")
        } catch let error as SequenceError {
            XCTAssertEqual(error.localizedDescription, SequenceError.notConfigured.localizedDescription)
        }
    }

    @MainActor
    func testUserIdentification() throws {
        let kit = Sequence.shared

        // Identify user
        kit.identify(userId: "test_user_123")

        // Reset should clear user
        kit.reset()
    }
    
    func testModelDecoding() throws {
        let json = """
        {
            "version": 1,
            "screens": [
                {
                    "id": "screen_1",
                    "name": "Welcome",
                    "type": "welcome",
                    "order": 0,
                    "content": {
                        "title": "Welcome!",
                        "subtitle": "Get started with our app",
                        "buttonText": "Continue",
                        "buttonAction": {
                            "type": "next"
                        },
                        "backgroundColor": "#0f172a",
                        "titleColor": "#ffffff",
                        "buttonColor": "#10b981"
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let config = try decoder.decode(OnboardingConfig.self, from: json)
        
        XCTAssertEqual(config.version, 1)
        XCTAssertEqual(config.screens.count, 1)
        XCTAssertEqual(config.screens[0].name, "Welcome")
        XCTAssertEqual(config.screens[0].type, .welcome)
        XCTAssertEqual(config.screens[0].content.title, "Welcome!")
    }
    
    func testButtonActionDecoding() throws {
        // Test next action
        let nextJson = """
        {"type": "next"}
        """.data(using: .utf8)!
        
        let nextAction = try JSONDecoder().decode(ButtonAction.self, from: nextJson)
        if case .next = nextAction {
            // Success
        } else {
            XCTFail("Expected .next action")
        }
        
        // Test complete action
        let completeJson = """
        {"type": "complete"}
        """.data(using: .utf8)!
        
        let completeAction = try JSONDecoder().decode(ButtonAction.self, from: completeJson)
        if case .complete = completeAction {
            // Success
        } else {
            XCTFail("Expected .complete action")
        }
        
        // Test screen action
        let screenJson = """
        {"type": "screen", "screenId": "abc123"}
        """.data(using: .utf8)!
        
        let screenAction = try JSONDecoder().decode(ButtonAction.self, from: screenJson)
        if case .screen(let screenId) = screenAction {
            XCTAssertEqual(screenId, "abc123")
        } else {
            XCTFail("Expected .screen action")
        }
    }
}

