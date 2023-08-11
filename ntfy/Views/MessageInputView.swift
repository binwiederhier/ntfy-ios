//
//  MessageInputView.swift
//  ntfy
//
//  Created by Nguyen Loc on 11/08/2023.
//

import SwiftUI

struct MessageInputView: View {
    @StateObject var viewModel: ViewModel
    @Binding var dismiss: Bool
    var body: some View {
        if #available(iOS 15.0, *) {
            content
        } else {
            // Fallback on earlier versions
            content
        }
    }
    
    @ViewBuilder
    var content: some View {
        ScrollView {
            VStack {
                Text("Publish to \(viewModel.subscription.displayName())")
                    .font(.title3)
                    .padding()
                Group {
                    TextField("Title", text: $viewModel.title)
                    TextField("Message", text: $viewModel.message)
                        .multilineTextAlignment(.leading)
                        .frame(minHeight: 200)
                    HStack {
                        TextField("Tags", text: $viewModel.tag)
                        Picker("Priority", selection: $viewModel.priority) {
                            ForEach(Priority.allCases, id: \.self) { item in
                                Text(item.title())
                            }
                        }
                    }
                }
                .padding()
                .border(Color("bgColor"))
                Spacer()
                Group {
                    Button {
                        Task {
                            await viewModel.send()                            
                        }
                        dismiss.toggle()
                    } label: {
                        Text("Send")
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .cornerRadius(8)
                    
                    Button {
                        dismiss.toggle()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.gray)
                    }
                    .cornerRadius(8)
                    .padding(.bottom, 10)
                }
                
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity)
        }
        .refreshable {
            dismiss.toggle()
        }
    }
}

struct MessageInputView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store.preview // Store.previewEmpty
        let sub = store.makeSubscription(store.context, "Nice", Store.sampleMessages["stats"]!)
        MessageInputView(viewModel: .init(subscription: sub, store: store), dismiss: .constant(false))
    }
}

enum Priority: Int, CaseIterable {
    case min = 1, low, normal, high, max
    func title() -> String {
        switch self {
        case .normal:
            return "Default Priority"
        case .high:
            return "High Priority"
        case .low:
            return "Low Priority"
        case .max:
            return "Max Priority"
        case .min:
            return "Min Priority"
        default:
            return "Default Priority"
        }
    }
}
