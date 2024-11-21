defmodule Mix.Tasks.Igniter.Task.TLSEnable do
  use Igniter.Mix.Task

  @example "mix igniter.task.TLSEnable --hostname beast.geuer-pollmann.de"

  @shortdoc "A short description of your task"

  @moduledoc """
  #{@shortdoc}

  Longer explanation of your task

  ## Example

  ```bash
  #{@example}
  ```

  ## Options

  * `--example-option` or `-e` - Docs for your option
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

    app_name =
      igniter
      |> Igniter.Project.Application.app_name()

    igniter
    |> add_deps()
    |> create_certificate_module()
    |> set_config_url_config_exs(hostname, endpoint_module, app_name)
    |> set_config_url_prod_exs(endpoint_module, app_name)
    |> create_launch_browser_task(hostname, endpoint_module)
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

  defp set_config_url_prod_exs(igniter, endpoint_module, app_name) do
    cert_module = Igniter.Project.Module.module_name(igniter, "Certificates")

    igniter
    |> Igniter.Project.Config.configure(
      "prod.exs",
      app_name,
      endpoint_module,
      http: [
        # {127, 0, 0, 1},
        ip: :any,
        port: 8080,
        http_1_options: [max_header_length: 32768]
      ],
      https: [
        ip: :any,
        port: 8443,
        cipher_suite: :strong,
        certfile: "/home/chgeuer/beast.geuer-pollmann.de.crt",
        keyfile: "/home/chgeuer/beast.geuer-pollmann.de.key",
        thousand_island_options: [
          transport_options: [
            sni_fun: &cert_module.sni_fun/1
            # socket_opts: [log_level: :info]
          ]
        ]
      ]
    )
  end

  defp create_launch_browser_task(igniter, hostname, endpoint_module) do
    igniter
    |> Igniter.Project.Module.create_module(
      Mix.Tasks.LaunchBrowser,
      ~s'''
      use Mix.Task

      def run(_) do
        url = "https://#{hostname}:\#{#{endpoint_module}.access_struct_url.port}/?\#{#{endpoint_module}.access_struct_url.query}"
        IO.puts("Opening browser at: \#{url}")
        System.cmd("/mnt/c/Windows/system32/cmd.exe", ["/C", "start \#{url}"])
      end
      '''
    )
    |> Igniter.Project.TaskAliases.add_alias("phx.server.browser", [
      "phx.server",
      "launch_browser"
    ])
  end

  defp create_certificate_module(igniter) do
    Igniter.Project.Module.create_module(
      igniter,
      Igniter.Libs.Phoenix.web_module_name(igniter, "Certificates"),
      ~s'''
      def cert_dir() do
        case :os.type() do
          {:unix, :linux} -> "/home/chgeuer"
          {:win32, :nt} -> "C:/Users/chgeuer/.lego/certificates"
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

  defp add_deps(igniter) do
    igniter
    |> Igniter.Project.Deps.add_dep(
      {:ssl_verify_fun, "~> 1.1.7", manager: :rebar3, override: true},
      append?: true
    )
    |> Igniter.Project.Deps.add_dep({:x509, "~> 0.8.7"}, append?: true)
  end
end
