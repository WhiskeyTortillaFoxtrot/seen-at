import Foundation
import SwiftData

struct SearchFilters {
    var league: String?
    var watchLocation: WatchLocation?
    var venueQuery = ""
    var dateRangeStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    var dateRangeEnd = Date()
    var dateRangeActive = false
    var playerNumber = ""
    var showMoreFilters = false

    var hasActiveFilters: Bool {
        league != nil || watchLocation != nil || !venueQuery.isEmpty || dateRangeActive || !playerNumber.isEmpty
    }
}

struct SearchOutcome {
    let events: [Event]
    let matchedEventIDs: Set<UUID>
}

/// The production search pipeline: a text or player-number query constrains events to the
/// matches it finds (a query that matches nothing yields an empty result set, not every
/// event), and active filters narrow either the matched events or, when no text query was
/// supplied, all events.
enum SearchQueryService {
    @MainActor
    static func search(
        term: String,
        numberTerm: String,
        filters: SearchFilters,
        context: ModelContext
    ) -> SearchOutcome {
        let term = term.trimmingCharacters(in: .whitespaces)
        let numberTerm = numberTerm.trimmingCharacters(in: .whitespaces)
        let hasTextQuery = !term.isEmpty || !numberTerm.isEmpty

        guard hasTextQuery || filters.hasActiveFilters else {
            return SearchOutcome(events: [], matchedEventIDs: [])
        }

        var candidateIDs = Set<UUID>()

        if !term.isEmpty {
            let titlePredicate = #Predicate<Event> { event in
                event.title.localizedStandardContains(term)
            }
            let titleDescriptor = FetchDescriptor<Event>(
                predicate: titlePredicate,
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            if let matched = try? context.fetch(titleDescriptor) {
                candidateIDs.formUnion(matched.map { $0.id })
            }

            let namePredicate = #Predicate<JerseySighting> { sighting in
                sighting.firstName?.localizedStandardContains(term) == true ||
                sighting.lastName?.localizedStandardContains(term) == true
            }
            let nameDescriptor = FetchDescriptor<JerseySighting>(predicate: namePredicate)
            if let matched = try? context.fetch(nameDescriptor) {
                candidateIDs.formUnion(matched.compactMap { $0.event?.id })
            }
        }

        if !numberTerm.isEmpty {
            let numberPredicate = #Predicate<JerseySighting> { sighting in
                sighting.playerNumber?.localizedStandardContains(numberTerm) == true
            }
            let numberDescriptor = FetchDescriptor<JerseySighting>(predicate: numberPredicate)
            if let matched = try? context.fetch(numberDescriptor) {
                candidateIDs.formUnion(matched.compactMap { $0.event?.id })
            }
        }

        var eventsToFilter: [Event]
        if !candidateIDs.isEmpty {
            let idList = Array(candidateIDs)
            let idPredicate = #Predicate<Event> { idList.contains($0.id) }
            let descriptor = FetchDescriptor<Event>(
                predicate: idPredicate,
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            eventsToFilter = (try? context.fetch(descriptor)) ?? []
        } else if hasTextQuery {
            // The query matched nothing, so the result set is empty — not every event.
            eventsToFilter = []
        } else {
            let allDescriptor = FetchDescriptor<Event>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            eventsToFilter = (try? context.fetch(allDescriptor)) ?? []
        }

        if filters.hasActiveFilters {
            if let league = filters.league {
                let teamNames = Set(
                    (try? context.fetch(
                        FetchDescriptor<Team>(predicate: #Predicate { $0.sport == league })
                    ))?.map { $0.name } ?? []
                )
                eventsToFilter = eventsToFilter.filter {
                    guard let away = $0.awayTeam, let home = $0.homeTeam else { return false }
                    return teamNames.contains(away) || teamNames.contains(home)
                }
            }

            if let watchLocation = filters.watchLocation {
                eventsToFilter = eventsToFilter.filter { $0.watchLocation == watchLocation }
            }

            let venueTerm = filters.venueQuery.trimmingCharacters(in: .whitespaces).lowercased()
            if !venueTerm.isEmpty {
                eventsToFilter = eventsToFilter.filter { $0.venue?.lowercased().contains(venueTerm) == true }
            }

            if filters.dateRangeActive {
                eventsToFilter = eventsToFilter.filter {
                    $0.date >= filters.dateRangeStart && $0.date <= filters.dateRangeEnd
                }
            }
        }

        return SearchOutcome(events: eventsToFilter, matchedEventIDs: candidateIDs)
    }
}
