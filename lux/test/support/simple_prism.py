from lux import Prism

class SimplePrism(Prism):
    id='aaace2b1-8089-4d4e-b68e-2ce904da12f0'
    name='Simple Prism'
    description='A very simple prism that greets you'
    input_schema={
        'type': 'object',
        'properties': {
            'name': {
                'type': 'string',
                'description': 'The name of the person to greet'
            }
        },
        'required': ['name']
    }
    output_schema={
        'type': 'object',
        'properties': {
            'message': {
                'type': 'string',
                'description': 'The greeting message'
            }
        }
    }

    def handler(self, input, context):
        return {
            'success': True,
            'data': {
                'message': f'Hello, {input.get("name", "prism")}!',
            }
        }

    @staticmethod
    def new():
        return SimplePrism()