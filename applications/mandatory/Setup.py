from includes.Application import Application
from includes.Config import Config


class Setup(Application):

    def install(self):
        self.run('cat /etc/debian_version')
        self.enquete.ask("accept", "Welcome. Use this at your own risk. Continue?", True)
        self.enquete.ask('port_ssh', 'Port SSH', 22)
        config_sshd = Config('/sshd_config.txt')
        config_sshd.use_space_separator()
        config_sshd.set('Port', self.enquete.answer('port_ssh'))
