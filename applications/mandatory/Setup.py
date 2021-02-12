from includes.Application import Application
from includes.Config import Config

class Setup(Application):

    def install(self):
        self.run('cat /etc/debian_version')
        self.getEnquete().ask("accept", "Welcome. Use this at your own risk. Continue?", True);
        self.getEnquete().ask('port_ssh', 'Port SSH', 22)
        config_sshd = Config('/sshd_config.txt');
        config_sshd.usesSpaceSeparator();
        config_sshd.set('Port', self.getEnquete().getAnswer('port_ssh'));
        
