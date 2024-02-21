function calculate_losses(type::Type{_PM.DCPPowerModel}, branches::Dict{String,Any})
    losses = Dict{String,Float64}()
    for (i, branch) in branches
        losses[i] = branch["pf"]^2 *branch["br_r"]
    end

    return losses
end

function calculate_losses(type::Type{_PM.ACPPowerModel}, branches::Dict{String,Any})
    losses = Dict{String,Float64}()
    for (i, branch) in branches
        losses[i] = sqrt((branch["pf"] + branch["pt"])^2 + (branch["qf"] + branch["qt"])^2)
    end

    return losses
end

function plot_losses(type::Type, data)
    branches = data["branch"]
    losses = calculate_losses(type, branches)

    bins = 200
    trace = histogram(x=collect(values(losses)), nbinsx=bins)
    layout = Layout(
        title_text="Histogram of Branch Losses",
        xaxis_title="MW (p.u)",
        yaxis_title="Count",
        plot_bgcolor="white"
    )

    plot(trace, layout)
end

function plot_prices(data)
    prices = [bus["lam_kcl_r"] for (i, bus) in data["bus"]]

    trace = scatter(x=1:length(prices), y=prices, mode="markers")
    layout = Layout(
        title_text="Locational Prices",
        yaxis_title="Price (\$/MWh)",
        yaxis_range=[-1000, 15000]
    )

    plot(trace, layout)
end

function plot_voltages(data)
    voltages = [bus["vm"] for (i, bus) in data["bus"]]

    bins = 200
    trace = histogram(x=voltages, nbinsx=bins)
    layout = Layout(
        title_text="Histogram of Bus Voltages",
        xaxis_title="Bus Voltage (p.u.)",
        yaxis_title="Count"
    )

    plot(trace, layout)
end

function plot_line_capacities(data)
    sij = [100 * ((sqrt((branch["pf"])^2 + (!isnan(branch["qf"]) ? branch["qf"] : 0)^2)) / branch["rate_a"]) for (i, branch) in data["branch"]]

    bins = 200
    trace = histogram(x=sij, nbinsx=bins)
    layout = Layout(
        title_text="Histogram of Line Loading",
        xaxis_title="% line loading",
        yaxis_title="Count",
        yaxis_range=[0, 450]
    )

    plot(trace, layout)
end