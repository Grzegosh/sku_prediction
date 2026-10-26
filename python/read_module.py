from pathlib import Path
from decimal import Decimal
import pandas as pd
from datetime import date
from psycopg2.errors import UndefinedTable

from python.sql_module import SQL



class ReadData:
    """Reads data from the gold layer into pandas, with a local Parquet cache."""

    def __init__(self, config_path, database: str = "prod", default_schema: str = "gold_sku"):
        self.sql = SQL(config_path)
        self.root = Path(config_path).resolve().parent  # repo root (where config.yaml lives)
        self.cache_dir = self.root / "cache"
        self.database = database
        self.default_schema = default_schema
        self.engine = self.sql.create_sqlalchemy_connection(database=database)

    def read_data(
        self,
        query: str = None,
        table_name: str = None
    ) -> pd.DataFrame:
        """
        Returns a DataFrame for either a whole table or a query defined in config.yaml
        (exactly one of them).
        Params:
            query (str): KEY of a query under postgres.queries in config.yaml (not SQL text).
            table_name (str): 'table' or 'schema.table'; reads the whole table.
        """
        if bool(query) == bool(table_name):
            raise ValueError("Provide exactly one of: query (config key) or table_name.")
        try:
            if table_name:
                sql_text = f"SELECT * FROM {table_name}"
        except UndefinedTable as e:
            print(f"Table {e} does not exists.")
            
        if not table_name:
                sql_text = self._read_query_file(query)

        data_frame = pd.read_sql(sql_text, self.engine)
        cleaned_df = self._clean_types(data_frame)
        return cleaned_df

    def _read_query_file(self, key: str) -> str:
        """Takes the SQL file path from config.yaml (postgres.queries.<key>) and reads it.
        The path is resolved against the folder of config.yaml, not against the working directory,
        so it also works when called from a notebook."""
        queries = self.sql.config.get_section("postgres")["queries"]
        if key not in queries:
            raise KeyError(f"Key '{key}' does not exist under postgres.queries in config.yaml.")
        path = self.root / queries[key]
        return path.read_text(encoding="utf-8")


    def _clean_types(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Takes a whole DataFrame and fixes the types of the dataframe columns.
        """
        for col in df.columns:
            if df[col].dtype != 'object':
                continue
            non_null = df[col].dropna()
            if non_null.empty:
                continue
            first = non_null.iloc[0]
            if isinstance(first, Decimal):
                df[col] = df[col].astype(float)
            elif isinstance(first, date):
                df[col] = pd.to_datetime(df[col])

        return df

