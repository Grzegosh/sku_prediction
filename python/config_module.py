import yaml

class Config:
    def __init__(self, path_to_config: str):
        try:
            with open(path_to_config, 'r') as file:
                self.config = yaml.safe_load(file)
        except FileNotFoundError:
            raise FileNotFoundError(f"Configuration file '{path_to_config}' not found.")


    def get_section(self, section: str):
        try:
            return self.config[section]
        except KeyError:
            raise KeyError(f"Section '{section}' not found in the config file.")