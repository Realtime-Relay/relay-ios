import SwiftUI

struct TopicInputView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var topic: String = ""
    @State private var isConnecting = false
    @State private var showChat = false
    @State private var apiKey = "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVQU9STjRWQkNXQzJORU1FVkpFWUY3VERIUVdYTUNLTExTWExNTjZRTjRBVU1WUElDSVJOSEpJRyIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDUwNTE2NjcsImp0aSI6IllVMG50TXFNcHhwWFNWbUp0OUJDazhhV0dxd0NwYytVQ0xwa05lWVBVcDNNRTNQWDBRcUJ2ZjBBbVJXMVRDamEvdTg2emIrYUVzSHVKUFNmOFB2SXJnPT0ifQ._LtZJnTADAnz3N6U76OaA-HCYq-XxckChk1WlHi_oZXfYP2vqcGIiNDFSQ-XpfjUTfKtXEuzcf_BDq54nSEMAA"
    @State private var secret = "SUAPWRWRITWYL4YP7B5ZHU3W2G2ZPYJ47IN4UWNHLMFTSIJEOMQJWWSWGY"
    @State private var showCredentials: Bool = true
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Enter Chat Details")
                    .font(.title)
                    .padding()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Topic")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextField("Enter chat topic", text: $topic)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextField("Enter your API key", text: $apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                    
                    Text("Secret")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextField("Enter your secret", text: $secret)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                }
                .padding(.horizontal)
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                Button(action: {
                    Task {
                        isConnecting = true
                        await viewModel.connect(
                            to: topic,
                            apiKey: apiKey.isEmpty ? nil : apiKey,
                            secret: secret.isEmpty ? nil : secret
                        )
                        isConnecting = false
                        if viewModel.isConnected {
                            showChat = true
                        }
                    }
                }) {
                    if isConnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Connect")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(topic.isEmpty || isConnecting)
                .padding(.horizontal)
            }
            .navigationTitle("Chat Demo")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showChat) {
                ChatView(viewModel: viewModel)
            }
        }
    }
} 
