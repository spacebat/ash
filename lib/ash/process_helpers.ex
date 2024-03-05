defmodule Ash.ProcessHelpers do
  @moduledoc """
  Helpers for working with processes and Ash actions.
  """

  @doc """
  Gets all of the ash context so it can be set into a new process.

  Use `transfer_context/1` in the new process to set the context.
  """
  @spec get_context_for_transfer(opts :: Keyword.t()) :: term
  def get_context_for_transfer(opts \\ []) do
    context = Ash.get_context()
    actor = Process.get(:ash_actor)
    authorize? = Process.get(:ash_authorize?)
    tenant = Process.get(:ash_tenant)

    dynamic_repo =
      case context[:dynamic_repo_module] do
        module when is_atom(module) ->
          {module, module.get_dynamic_repo()}

          _ ->
          nil
      end

    tracer = Process.get(:ash_tracer)

    tracer_context =
      opts[:tracer]
      |> List.wrap()
      |> Enum.concat(List.wrap(tracer))
      |> Map.new(fn tracer ->
        {tracer, Ash.Tracer.get_span_context(tracer)}
      end)

    %{
      context: context,
      actor: actor,
      tenant: tenant,
      dynamic_repo: dynamic_repo,
      authorize?: authorize?,
      tracer: tracer,
      tracer_context: tracer_context
    }
  end

  @spec transfer_context(term, opts :: Keyword.t()) :: :ok
  def transfer_context(
        %{
          context: context,
          actor: actor,
          tenant: tenant,
          dynamic_repo: dynamic_repo,
          authorize?: authorize?,
          tracer: tracer,
          tracer_context: tracer_context
        },
        _opts \\ []
      ) do
    case actor do
      {:actor, actor} ->
        Ash.set_actor(actor)

      _ ->
        :ok
    end

    case tenant do
      {:tenant, tenant} ->
        Ash.set_tenant(tenant)

      _ ->
        :ok
    end

    case dynamic_repo do
      {dynamic_repo_module, dynamic_repo} ->
        dynamic_repo_module.put_dynamic_repo(dynamic_repo)

      _ ->
        :ok
    end

    case authorize? do
      {:authorize?, authorize?} ->
        Ash.set_authorize?(authorize?)

      _ ->
        :ok
    end

    Ash.set_tracer(tracer)

    Enum.each(tracer_context || %{}, fn {tracer, tracer_context} ->
      Ash.Tracer.set_span_context(tracer, tracer_context)
    end)

    Ash.set_context(context)
  end
end
