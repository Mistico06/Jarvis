import SwiftUI

struct MessageRow: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                Text(message.content)
                    .padding(10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            } else {
                Text(message.content)
                    .padding(10)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(10)
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}
