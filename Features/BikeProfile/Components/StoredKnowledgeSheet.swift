//
//  StoredKnowledgeSheet.swift
//  PID Hunter
//
//  Created by Ahmed Al Qady on 11/07/2026.
//

import SwiftUI

struct StoredKnowledgeSheet: View {

    let profile: BikeProfile
    let classification: DiscoveryClassification

    private var discoveries: [(key: DiscoveryKey, value: BikeKnowledge)] {
        profile.discoveries
            .filter { $0.value.classification == classification }
            .sorted { $0.key.request < $1.key.request }
    }

    var body: some View {

        NavigationStack {

            ScrollView {

                LazyVStack(spacing: 12) {

                    ForEach(discoveries, id: \.key) { item in

                        StoredPIDCard(
                            key: item.key,
                            knowledge: item.value
                        )

                    }

                }
                .padding()

            }
            .navigationTitle("\(classification.title) (\(discoveries.count))")
            .navigationBarTitleDisplayMode(.inline)

        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)

    }

}
