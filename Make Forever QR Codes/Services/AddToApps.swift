//
//  AddToApps.swift
//  Make Forever QR Codes
//
//  Apple's own "add contact" and "add event" screens. The person decides
//  what gets saved; the app never reads their contacts or calendar.
//

import ContactsUI
import EventKit
import EventKitUI
import SwiftUI

/// Shows a scanned contact with Apple's "Create New Contact" button.
struct ContactAdder: UIViewControllerRepresentable {
    let contact: CNContact
    let onDone: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = CNContactViewController(forUnknownContact: contact)
        controller.contactStore = CNContactStore()
        controller.allowsActions = true
        controller.allowsEditing = true
        controller.delegate = context.coordinator
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .close, primaryAction: UIAction { _ in onDone() })
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            onDone()
        }
    }
}

/// Apple's "New Event" screen, filled in with the scanned event.
struct EventAdder: UIViewControllerRepresentable {
    let info: EventInfo
    let onDone: () -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = info.title.isEmpty ? "Event" : info.title
        let start = info.start ?? Date()
        event.startDate = start
        event.endDate = max(info.end ?? start.addingTimeInterval(3600), start)
        event.isAllDay = info.allDay
        event.location = info.location.isEmpty ? nil : info.location
        event.notes = info.notes.isEmpty ? nil : info.notes

        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }

        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            onDone()
        }
    }
}
