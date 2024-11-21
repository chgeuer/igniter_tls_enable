defmodule Mix.Tasks.Igniter.Task.TLSEnable do
  use Igniter.Mix.Task

  @deps [
    {:ssl_verify_fun, "~> 1.1.7", manager: :rebar3, override: true},
    {:x509, "~> 0.8.7"}
  ]

  @example "mix Igniter.Task.TLSEnable --hostname beast.geuer-pollmann.de"

  @shortdoc "Enables TLS for your Phoenix project using certificates from Let's Encrypt which are stored in your home directory."

  @moduledoc """
  #{@shortdoc}

  Longer explanation of your task

  ## Example

  ```bash
  #{@example}
  ```

  ## Options

  * `--hostname` or `-h` - Hostname for the certificate
  """

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      # Groups allow for overlapping arguments for tasks by the same author
      # See the generators guide for more.
      group: :igniter_test,
      # dependencies to add
      adds_deps: [],
      # dependencies to add and call their associated installers, if they exist
      installs: [],
      # An example invocation
      example: @example,
      # a list of positional arguments, i.e `[:file]`
      positional: [],
      # Other tasks your task composes using `Igniter.compose_task`, passing in the CLI argv
      # This ensures your option schema includes options from nested tasks
      composes: [],
      # `OptionParser` schema
      schema: [{:hostname, :string}],
      # Default values for the options in the `schema`
      defaults: [],
      # CLI aliases
      aliases: [
        h: :hostname
      ],
      # A list of options in the schema that are required
      required: [:hostname]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter, _argv) do
    opts = igniter.args.options
    hostname = opts[:hostname]

    endpoint_module =
      igniter
      |> Igniter.Libs.Phoenix.web_module_name("Endpoint")

    cert_module =
      igniter
      |> Igniter.Libs.Phoenix.web_module_name("Certificates")

    app_name =
      igniter
      |> Igniter.Project.Application.app_name()

    igniter
    |> add_deps(@deps)
    |> create_certificate_module(cert_module)
    |> set_config_url_config_exs(hostname, endpoint_module, app_name)
    |> set_config_url_exs("prod.exs", app_name, endpoint_module, cert_module, hostname)
    # |> set_config_url_exs("dev.exs", app_name, endpoint_module, cert_module, hostname)
    |> create_launch_browser_task(endpoint_module)
  end

  defp set_config_url_config_exs(igniter, hostname, endpoint_module, app_name) do
    igniter
    |> Igniter.Project.Config.configure(
      "config.exs",
      app_name,
      [endpoint_module, :url, :host],
      hostname
    )
  end

  defp set_config_url_exs(igniter, file_name, app_name, endpoint_module, cert_module, hostname)
       when is_atom(endpoint_module) and is_atom(cert_module) do
    igniter
    |> Igniter.Project.Config.configure(
      file_name,
      app_name,
      endpoint_module,
      http: [
        ip: :any,
        port: 8080,
        http_1_options: [max_header_length: 32768]
      ],
      https: [
        ip: :any,
        port: 8443,
        cipher_suite: :strong,
        certfile: Path.join([System.user_home(), "#{hostname}.crt"]),
        keyfile: Path.join([System.user_home(), "#{hostname}.key"]),
        thousand_island_options: [
          transport_options: [
            sni_fun: &cert_module.sni_fun/1
            # socket_opts: [log_level: :info]
          ]
        ]
      ]
    )
  end

  defp create_launch_browser_task(igniter, endpoint_module)
       when is_atom(endpoint_module) do
    igniter
    |> Igniter.Project.Module.create_module(
      Mix.Tasks.LaunchBrowser,
      ~s'''
      use Mix.Task

      defp by_os(%{mac: mac, linux: linux, wsl: wsl, windows: windows}) do
        case :os.type() do
          {:unix, :darwin} ->
            mac

          {:unix, _} ->
            case System.get_env("WSL_DISTRO_NAME") do
              nil -> linux
              x when is_binary(x) -> wsl
            end

          {:win32, _} ->
            windows
        end
      end

      def run(_) do
        url = #{endpoint_module}.url()
        IO.puts("Opening browser at: \#{url}")

        %{
          mac:     {"open", [url]},
          linux:   {"xdg-open", [url]},
          wsl:     {"/mnt/c/Windows/system32/cmd.exe", ["/C", "start \#{url}"]},
          windows: {"cmd.exe", ["/C", "start \#{url}"]}
        }
        |> by_os()
        |> then(fn {command, args} -> System.cmd(command, args) end)
      end
      '''
    )
    |> Igniter.Project.TaskAliases.add_alias("phx.server.browser", [
      "phx.server",
      "launch_browser"
    ])
  end

  defp create_certificate_module(igniter, cert_module) when is_atom(cert_module) do
    Igniter.Project.Module.create_module(
      igniter,
      cert_module,
      ~s'''
      def cert_dir() do
        case :os.type() do
          {:unix, :linux} -> System.user_home()
          {:win32, :nt} -> Path.join([System.user_home(), ".lego", "certificates"])
        end
      end

      def sni_fun(host),
        do: [
          cert:
            host
            |> to_string
            |> (fn h -> "\#{cert_dir()}/\#{h}.crt" end).()
            |> File.read!()
            |> X509.Certificate.from_pem!()
            |> X509.Certificate.to_der(),
          key:
            host
            |> to_string
            |> (fn h -> "\#{cert_dir()}/\#{h}.key" end).()
            |> File.read!()
            |> X509.PrivateKey.from_pem!()
            |> X509.PrivateKey.to_der(wrap: true)
            |> (fn k -> {:PrivateKeyInfo, k} end).()
        ]
      '''
    )
  end

  defp add_deps(igniter, deps) do
    Enum.reduce(deps, igniter, fn d, i ->
      Igniter.Project.Deps.add_dep(i, d, append?: true)
    end)
  end
end
