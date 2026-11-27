# Dane do punktu 17 (liczba aktywnych SKU)

Pliki CSV odtworzone z surowych plików parquet (`data/fact_sales`, `data/dim_product`, `data/dim_category`) według tej samej logiki co modele dbt (silver → gold). Zgadzają się z hurtownią: suma przychodu 644 115 980,27, sztuki roczne 225 322 / 226 099 / 253 583 / 260 440 / 256 959, 1826 dni.

| Plik | Wiersze | Odpowiednik w hurtowni | Kolumny |
|---|---|---|---|
| `fact_sales_agg_daily_sku.csv` | 340 146 | `gold_sku.fact_sales_agg_daily_sku` | `date`, `sku_id`, `units_sold`, `revenue`, `stockout_attempts`, `stockout_units` |
| `fact_sales_agg_daily.csv` | 1 826 | `gold_sku.fact_sales_agg_daily` | `date`, `units_sold`, `revenue`, `stockout_attempts`, `stockout_units` |
| `dim_product.csv` | 287 | `silver_sku.dim_product` | `sku_id`, `sku_name`, `category_id`, `brand`, `current_price`, `discontinued_date`, `valid_from`, `launch_date`, `valid_to` |
| `dim_category.csv` | 8 | `silver_sku.dim_category` | `id`, `category_name`, `category_group` |

Co trzeba wiedzieć:

- `fact_sales_agg_daily_sku.csv` to GĘSTA siatka: ma wiersz dla każdego SKU i każdego dnia, w którym SKU jest w katalogu (od `launch_date` do końca `valid_to`), także gdy nic nie sprzedał (wtedy `units_sold = 0`). Samo wystąpienie SKU w tabeli NIE oznacza więc, że SKU był aktywny. Aktywny SKU = wiersz z `units_sold > 0`.
- Kanały są już zsumowane (tabela jest na poziomie dzień × SKU).
- `dim_product.csv` jest wersjonowana: jeden SKU ma od 1 do 3 wierszy (zmiana ceny, marki albo kategorii). Otwarty okres ma `valid_to = 9999-12-31`. Liczenie SKU: `nunique` po `sku_id`, nie liczba wierszy.
- `revenue` w gold nie uwzględnia rabatu (`quantity × unit_price`).
- 254 linie sprzedaży (0,03% przychodu) nie trafiły do tabeli gold, bo ich data wypada poza okresem obecności SKU w katalogu (m.in. przed `launch_date`).
