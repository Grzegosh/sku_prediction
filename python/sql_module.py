from python.config_module import Config
from pathlib import Path
import pandas as pd 
from sqlalchemy import create_engine
import os 
import psycopg2

class SQL:
    def __init__(self, config_path: str):
        self.config = Config(config_path)
        self.database = self.config.get_section("postgres")["database"] # Default database.
        self.user = self.config.get_section("postgres")["user"]
        self.host = self.config.get_section("postgres")["host"]

    def create_connection(self, database:str = None) -> psycopg2.extensions.connection:
        """
        Function that tests the connection to the database using the provided
        configuration parameters.
        Returns the connection object if the connection is successful, otherwise raises an exception.
        """
        try:
            conn = psycopg2.connect(
                host = self.host,
                database = database if database else self.database,
                user = self.user
            )
            conn.autocommit = True
            return conn
        except psycopg2.OperationalError as e:
            raise ConnectionError(f"Failed to connect to the database: {e}")

    def create_sqlalchemy_connection(self, database:str = None):
        engine = create_engine(f'postgresql+psycopg2://{self.user}:password@{self.host}/{database}')
        return engine

    def read_query(self, query: str) -> str:
        """
        Function that reads a query from configuration file.
        Params:
            query (str): The query key to be read from the configuration file.
        """
        try:
            query_path = self.config.get_section("postgres")['queries'][query]
            with open (query_path, 'r') as file:
                return file.read()
        except KeyError:
            raise KeyError(f"Key: {query} does not exists in the configuration file.")
        


    def create_database(self, database_name: str) -> None:
        """
        Function that creates a new schema in particular
        database using the provided configuration parameters.
        Params:
            database_name (str): The name of the database to be created. Can contain only two values: 'dev' or 'prod'.
        Raises:
            ValueError: If the provided database_name is not 'dev' or 'prod'.
        """
        if database_name not in ['dev', 'prod']:
            raise ValueError(f"Invalid database name '{database_name}'. Must be 'dev' or 'prod'.")

        conn = self.create_connection()
        conn.autocommit = True
        if database_name == 'dev':
            query = self.read_query("create_dev_db")
        else:
            query = self.read_query("create_prod_db")

        try:
            with conn.cursor() as cursor:
                cursor.execute(query)
                print(f"Query {query} executed successfully.")
                cursor.close()
        except Exception as e:
            print(f"Error executing query: {e}")

    def create_schemas(self, database_name: str) -> None:
        """
        Function that creates schemas in particular
        database using the provided information in the 
        configuration file.
        Params:
            database_name (str): The name of the database in which schemas will be created. Can contain only two values: 'dev' or 'prod'.
        """
        if database_name not in ['dev', 'prod']:
            raise ValueError(f"Invalid database name '{database_name}'. Must be 'dev' or 'prod'.")

        conn = self.create_connection(database=database_name)
        query = self.read_query("create_schemas")

        try:
            with conn.cursor() as cursor:
                cursor.execute(query)
                print(f"Query {query} executed successfully.")
                cursor.close()
        except Exception as e:
            print(f"Error executing query: {e}")

    def create_tables(self, database_name: str = 'dev') -> None:
        """
        Function that creates tables in particular
        database in bronze schema.
        Params:
            database_name (str): The name of the database in which tables will be created. Can contain only two values: 'dev' or 'prod'.
        """
        if database_name not in ['dev', 'prod']:
            raise ValueError(f"Invalid database name '{database_name}'. Must be 'dev' or 'prod'.")

        conn = self.create_connection(database=database_name)
        queries = ['create_dim_category','create_dim_customer','create_dim_date','create_dim_product','create_fact_sales']

        for query_key in queries:
            query = self.read_query(query_key)
            try:
                with conn.cursor() as cursor:
                    cursor.execute(query)
                    print(f"Query {query} executed successfully.")
                    cursor.close()
            except Exception as e:
                print(f"Error executing query: {e}")

    def load_data_into_bronze(self, database_name: str = 'dev', table: str = None) -> None:
        """
        Function that loades data into specific table.
        Params:
            table: A name of the table in the bronze layer. Can be 'customer','category','date','product' or 'sales'.
            database_name: A name of the database name. Can be 'dev' or 'prod'.
        """
        if database_name not in ['dev', 'prod']:
            raise ValueError(f"Invalid database name '{database_name}'. Must be 'dev' or 'prod'.")

        if table not in ['category', 'customer', 'date', 'product', 'sales']:
            raise ValueError(f"Invalid table name '{table}'. Must be 'category', 'customer', 'date', 'product' or 'sales'.")

        conn = self.create_sqlalchemy_connection(database=database_name)
        base_data_path = Path(__file__).parent.parent / 'data'
        suffix = '.parquet'
        if table == 'category':
            base_dir = Path(base_data_path) / 'dim_category'
            _dirs = os.listdir(base_dir)

            for dir in _dirs:
                data_folder_path = Path(base_dir) / f'{dir}'
                __dirs = os.listdir(data_folder_path)
                filenames = [file for file in __dirs if file.endswith(suffix)]
                for data_file in filenames:
                    full_data_path = data_folder_path / f'{data_file}'
                    df = pd.read_parquet(full_data_path)
                    df.rename(columns={
                        '_source_system': 'source_system'
                        ,'_ingested_at': 'ingested_at'
                    }, inplace=True)
                    try:
                        df.to_sql(
                            name='source_category',
                            schema='bronze',
                            if_exists='append',
                            index=False,
                            con=conn
                        )
                    except Exception as e:
                        print(f"Error executing: {str(e).split("DETAIL")[0]}")

        elif table == 'customer':
            base_dir = Path(base_data_path) / 'dim_customer'
            _dirs = os.listdir(base_dir)

            for dir in _dirs:
                data_folder_path = Path(base_dir) / f'{dir}'
                __dirs = os.listdir(data_folder_path)
                filenames = [file for file in __dirs if file.endswith(suffix)]
                for data_file in filenames:
                    full_data_path = data_folder_path / f'{data_file}'
                    df = pd.read_parquet(full_data_path)
                    df.rename(columns={
                        '_source_system': 'source_system'
                        ,'_ingested_at': 'ingested_at'
                        ,'customer_id': 'id'
                    }, inplace=True)
                    try:
                        df.to_sql(
                            name='source_customer',
                            schema='bronze',
                            if_exists='append',
                            index=False,
                            con=conn
                        )
                    except Exception as e:
                        print(f"Error executing: {str(e).split("DETAIL")[0]}")

        elif table == 'date':
            base_dir = Path(base_data_path) / 'dim_date'
            _dirs = os.listdir(base_dir)

            for dir in _dirs:
                data_folder_path = Path(base_dir) / f'{dir}'
                __dirs = os.listdir(data_folder_path)
                filenames = [file for file in __dirs if file.endswith(suffix)]
                for data_file in filenames:
                    full_data_path = data_folder_path / f'{data_file}'
                    df = pd.read_parquet(full_data_path)
                    df.rename(columns={
                        '_source_system': 'source_system'
                        ,'_ingested_at': 'ingested_at'
                        ,'customer_id': 'id'
                    }, inplace=True)
                    try:
                        df.to_sql(
                            name='source_date',
                            schema='bronze',
                            if_exists='append',
                            index=False,
                            con=conn
                        )
                    except Exception as e:
                        print(f"Error executing: {str(e).split("DETAIL")[0]}")

        elif table == 'product':
                base_dir = Path(base_data_path) / 'dim_product'
                _dirs = os.listdir(base_dir)
    
                for dir in _dirs:
                    data_folder_path = Path(base_dir) / f'{dir}'
                    __dirs = os.listdir(data_folder_path)
                    filenames = [file for file in __dirs if file.endswith(suffix)]
                    for data_file in filenames:
                        full_data_path = data_folder_path / f'{data_file}'
                        df = pd.read_parquet(full_data_path)
                        df.rename(columns={
                            '_source_system': 'source_system'
                            ,'_ingested_at': 'ingested_at'
                            ,'sku_id': 'id'
                        }, inplace=True)
                        try:
                            df.to_sql(
                                name='source_product',
                                schema='bronze',
                                if_exists='append',
                                index=False,
                                con=conn
                            )
                        except Exception as e:
                            print(f"Error executing: {str(e).split("DETAIL")[0]}")

        else:
            base_dir = Path(base_data_path) / 'fact_sales'
            _dirs = os.listdir(base_dir)
            for dir in _dirs:
                data_folder_path = Path(base_dir) / f'{dir}'
                __dirs = os.listdir(data_folder_path)
                filenames = [file for file in __dirs if file.endswith(suffix)]
                for data_file in filenames:
                    full_data_path = data_folder_path / f'{data_file}'
                    df = pd.read_parquet(full_data_path)
                    df['discount_pct_raw'] = df['discount_pct_raw'].fillna(0.0)
                    df['discount_pct_raw'] = df['discount_pct_raw'].replace('',0)
                    df['unit_price_raw'] = [float(str(x).split(' ')[0].replace(',','.')) for x in df['unit_price_raw']]
                    df['order_ts_raw'] = pd.to_datetime(df['order_ts_raw'], format='mixed').dt.strftime('%Y-%m-%d')
                    try:
                        df.to_sql(
                            name='source_sales',
                            schema='bronze',
                            if_exists='append',
                            index=False,
                            con=conn
                        )
                    except Exception as e:
                        print(f"Error executing: {str(e).split("DETAIL")[0]}")

 
    def setup_pipeline(self) -> None:
        """
        Function that sets up the entire pipeline by creating databases
        and schemas as specified in the configuration file.
        It's also responsible for ingesting the raw data into the bronze schema.
        """
        for database in ['dev', 'prod']:
            self.create_database(database_name=database)
            self.create_schemas(database_name=database)
            self.create_tables(database_name=database)
            for table in ['category', 'customer', 'date', 'product', 'sales']:
                self.load_data_into_bronze(
                    database_name=database,
                    table=table
                )


    