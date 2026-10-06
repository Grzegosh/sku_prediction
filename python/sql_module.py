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

        conn = self.create_sqlalchemy_connection('dev')
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
                        print(f"Error executing: {e}")

                
            
            
        

    
    def setup_pipeline(self) -> None:
        """
        Function that sets up the entire pipeline by creating databases
        and schemas as specified in the configuration file.
        """
        self.create_database("dev")
        self.create_database("prod")
        self.create_schemas("dev")
        self.create_schemas("prod")
        self.create_tables("dev")
        self.create_tables("prod")

    