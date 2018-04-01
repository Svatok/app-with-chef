# encoding: utf-8
# author: Dmitry Mischenko

class PostgresExtension < Inspec.resource(1)
  name 'postgres_extension'
  desc 'Use the postgres_extension InSpec audit resource to test installation of PostgreSQL database extensions'
  example "
    describe postgres_extension('9.6', 'main', 'cube', 'test01') do
      it { should be_installed }
    end
  "

  def initialize(version, cluster, name, db = 'postgres')
    @name = name
    @db = db
    @port = get_port(version, cluster)
  end

  def installed?
    return true if query('SELECT extname FROM pg_extension').include? @name
    false
  end

  def to_s
    "Extension #{@name}"
  end

  private

  def query(query)
    psql_cmd = create_psql_cmd(query, @db)
    cmd = inspec.command(psql_cmd)
    out = cmd.stdout + "\n" + cmd.stderr
    if cmd.exit_status != 0 || out =~ /could not connect to .*/ || out.downcase =~ /^error:.*/
      false
    else
      cmd.stdout.strip
    end
  end

  def escaped_query(query)
    Shellwords.escape(query)
  end

  # TODO: You cannot specify multiple DBs
  def create_psql_cmd(query, db)
    "su postgres -c \"psql -d #{db} -p #{@port} -q -t -c #{escaped_query(query)}\""
  end

  def get_port(version, cluster)
    postmaster_content = inspec.command("cat /var/lib/postgresql/#{version}/#{cluster}/postmaster.pid").stdout.split
    postmaster_content[3].to_i
  end
end
