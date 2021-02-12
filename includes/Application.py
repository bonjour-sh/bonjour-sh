class Application:

    questions = [];
    actions = [];

    def __init__(self, enquete):
        self.enquete = enquete

    def getEnquete(self):
        return self.enquete;

    def announce(self, message):
        print('Attention: ' + message)

    def run(self, command):
        self.announce('Executing ' + command)
        #self.editConfig()

