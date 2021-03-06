#-*-Mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et nomod:

defmodule CloudICore.Mixfile do
  use Mix.Project

  def project do
    [app: :cloudi_core,
     version: "1.7.2",
     language: :erlang,
     description: description(),
     package: package(),
     deps: deps()]
  end

  def application do
    [applications: [
       :nodefinder,
       :pqueue,
       :quickrand,
       :supool,
       :varpool,
       :trie,
       :reltool_util,
       :key2value,
       :keys1value,
       :uuid,
       :erlang_term,
       :cpg,
       :syslog_socket,
       :msgpack,
       :sasl,
       :syntax_tools],
     mod: {:cloudi_core_i_app, []},
     registered: [
       :cloudi_core_i_configurator,
       :cloudi_core_i_logger,
       :cloudi_core_i_logger_sup,
       :cloudi_core_i_nodes,
       :cloudi_core_i_os_spawn,
       :cloudi_core_i_services_external_sup,
       :cloudi_core_i_services_internal_reload,
       :cloudi_core_i_services_internal_sup,
       :cloudi_core_i_services_monitor]]
  end

  defp deps do
    [{:cpg, "~> 1.7.2"},
     {:uuid, "~> 1.7.2", hex: :uuid_erl},
     {:reltool_util, "~> 1.7.2"},
     {:trie, "~> 1.7.2"},
     {:erlang_term, "~> 1.7.2"},
     {:quickrand, "~> 1.7.2"},
     {:pqueue, "~> 1.7.2"},
     {:key2value, "~> 1.7.2"},
     {:keys1value, "~> 1.7.2"},
     {:nodefinder, "~> 1.7.2"},
     {:supool, "~> 1.7.2"},
     {:varpool, "~> 1.7.2"},
     {:syslog_socket, "~> 1.7.2"},
     {:msgpack, "~> 0.7.0"}]
  end

  defp description do
    "Erlang/Elixir Cloud Framework"
  end

  defp package do
    [files: ~w(src include doc test rebar.config README.markdown LICENSE
               cloudi.conf),
     maintainers: ["Michael Truog"],
     licenses: ["MIT"],
     links: %{"Website" => "http://cloudi.org",
              "GitHub" => "https://github.com/CloudI/cloudi_core"}]
   end
end
