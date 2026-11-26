package com.ivy.data.remote.impl

import arrow.core.Either
import arrow.core.left
import arrow.core.raise.catch
import com.ivy.data.remote.RemoteExchangeRatesDataSource
import com.ivy.data.remote.responses.ExchangeRatesResponse
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.double
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import javax.inject.Inject

/**
 * Free, key-less sources, tried in order until one works:
 * 1. fawazahmed0/exchange-api through the jsDelivr CDN (CC0, no rate limits, daily)
 * 2. the same data on Cloudflare Pages (independent CDN)
 * 3. open.er-api.com (ExchangeRate-API open access, daily, rate limited, attribution)
 */
class RemoteExchangeRatesDataSourceImpl @Inject constructor(
    private val ktorClient: dagger.Lazy<HttpClient>,
) : RemoteExchangeRatesDataSource {
    private val urls = listOf(
        "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/eur.min.json",
        "https://latest.currency-api.pages.dev/v1/currencies/eur.min.json",
        "https://currency-api.pages.dev/v1/currencies/eur.min.json",
        "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/eur.json",
    )
    private val fallbackUrl = "https://open.er-api.com/v6/latest/EUR"

    override suspend fun fetchEurExchangeRates(): Either<String, ExchangeRatesResponse> {
        var latestResult: Either<String, ExchangeRatesResponse> = "Impossible".left()
        for (url in urls) {
            latestResult = fetchEurExchangeRates(url)
            if (latestResult.isRight()) {
                return latestResult
            }
        }
        val fallback = fetchFromOpenErApi()
        return if (fallback.isRight()) fallback else latestResult
    }

    private suspend fun fetchEurExchangeRates(
        url: String
    ): Either<String, ExchangeRatesResponse> = catch({
        Either.Right(ktorClient.get().get(url).body<ExchangeRatesResponse>())
    }) { e ->
        Either.Left(e.message ?: "Error fetching exchange rates")
    }

    private suspend fun fetchFromOpenErApi(): Either<String, ExchangeRatesResponse> = catch({
        val json = ktorClient.get().get(fallbackUrl).body<JsonObject>()
        val rates = json["rates"]?.jsonObject
            ?.mapKeys { it.key.lowercase() }
            ?.mapValues { it.value.jsonPrimitive.double }
            ?: error("No rates in response")
        Either.Right(
            ExchangeRatesResponse(
                date = json["time_last_update_utc"]?.jsonPrimitive?.content ?: "",
                rates = rates
            )
        )
    }) { e ->
        Either.Left(e.message ?: "Error fetching exchange rates")
    }
}
