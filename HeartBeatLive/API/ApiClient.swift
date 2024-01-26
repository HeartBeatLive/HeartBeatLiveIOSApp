//
//  ApiClient.swift
//  HeartBeatLive
//
//  Created by Nikita Ivchenko on 04.09.2022.
//

import Apollo
import FirebaseAuth

class ApiClient {
    static let shared: ApolloClient = {
        guard let url = URL(string: "\(Config.serverScheme)://\(Config.serverHost)/graphql") else {
            fatalError("Failed to build GraphQL URL.")
        }

        let store = ApolloStore(cache: InMemoryNormalizedCache())
        let provider = NetworkInterceptorProvider(store: store, client: URLSessionClient())
        let transport = RequestChainNetworkTransport(interceptorProvider: provider,
                                                     endpointURL: url)
        
        return ApolloClient(networkTransport: transport, store: store)
    }()
}

struct NetworkInterceptorProvider: InterceptorProvider {
    var store: ApolloStore
    var client: URLSessionClient
    
    func interceptors<Operation>(for operation: Operation) -> [ApolloInterceptor] where Operation: GraphQLOperation {
        return [
            AuthorizationApolloInterceptor(),
            MaxRetryInterceptor(),
            CacheReadInterceptor(store: self.store),
            NetworkFetchInterceptor(client: self.client),
            ResponseCodeInterceptor(),
            JSONResponseParsingInterceptor(cacheKeyForObject: self.store.cacheKeyForObject),
            AutomaticPersistedQueryInterceptor(),
            CacheWriteInterceptor(store: self.store)
        ]
    }
}

private class AuthorizationApolloInterceptor: ApolloInterceptor {
    func interceptAsync<Operation>(
        chain: RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void
    ) where Operation: GraphQLOperation {
        guard let user = Auth.auth().currentUser else {
            return chain.proceedAsync(request: request, response: response, completion: completion)
        }
        
        user.getIDToken { idToken, error in
            guard error == nil else { return }
            guard let idToken = idToken else { return }
            
            request.addHeader(name: "Authorization", value: "Bearer \(idToken)")
         
            chain.proceedAsync(request: request, response: response, completion: completion)
        }
    }
}
