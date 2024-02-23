create_chunks(arr, n) = [arr[i:min(i + n - 1, end)] for i in 1:n:length(arr)]

function plot_fcas(data)
    for (service_name, service) in sort!(collect(fcas_services), by=x -> x[2].id)
        gens = get_fcas_participants(data["gen"], service)
        loads = get_fcas_participants(data["load"], service)

        if length(gens) + length(loads) == 0
            continue
        end

        chunks = create_chunks(sort!(collect(gens), by=x -> x[2]["index"]), 10)

        for chunk in chunks

            titles = Array{Union{Missing,String}}(missing, 2, 5)
            for (i, subchunk) in enumerate(create_chunks(chunk, 5))
                values = ["Generator $(first(j)), ($(last(j)["fuel"]))" for k in 1:1, j in subchunk]
                titles[i, 1:length(values)] = values
            end

            fig = make_subplots(rows=length(titles[1, :]), cols=2, subplot_titles=titles)

            col_index = 1
            row_index = 1
            for (i, gen) in chunk
                n = parse(Int, i)

                fcas = gen["fcas"][service.id]

                t1 = scatter(
                    name="Generator $(i)",
                    mode="line",
                    x=[fcas["emin"], fcas["lb"], fcas["ub"], fcas["emax"]],
                    y=[0, fcas["amax"], fcas["amax"], 0],
                    marker=attr(
                        color="Black",
                        size=0,
                        line=attr(
                            color="Black",
                            width=2
                        )
                    ),
                    showlegend=false,
                )

                p_energy = [data["gen"]["$n"]["pg"]]
                p_fcas = [data["gen"]["$n"]["gen_$(fcas_name(service))"]]

                p_min = gen["pmin"]
                p_max = gen["pmax"]

                t2 = scatter(
                    mode="markers",
                    x=p_energy,
                    y=p_fcas,
                    marker=attr(
                        color="Green",
                        size=8,
                        line=attr(
                            color="Green",
                            width=2
                        ),
                        symbol="x"
                    ),
                    showlegend=false,
                )
                
                t3 = scatter(
                    mode="markers",
                    x=[p_min, p_max],
                    y=[0, 0],
                    marker=attr(
                        color="Red",
                        size=0,
                        line=attr(
                            color="Red",
                            width=2
                        ),
                        symbol="line-ns"
                    ),
                    showlegend=false,
                )

                add_trace!(fig, t1, row=row_index, col=col_index)
                add_trace!(fig, t2, row=row_index, col=col_index)
                add_trace!(fig, t3, row=row_index, col=col_index)

                if (row_index % 5 == 0)
                    row_index = 1
                    col_index += 1
                else
                    row_index += 1
                end
            end

            relayout!(fig, 
                title_text=fcas_name(service)
            )

            display(fig)
        end

        chunks = create_chunks(sort!(collect(loads), by=x -> x[2]["index"]), 10)

        for chunk in chunks

            titles = Array{Union{Missing,String}}(missing, 2, 5)
            for (i, subchunk) in enumerate(create_chunks(chunk, 5))
                values = ["Load $(first(j))" for k in 1:1, j in subchunk]
                titles[i, 1:length(values)] = values
            end

            fig = make_subplots(rows=length(titles[1, :]), cols=2, subplot_titles=titles)

            col_index = 1
            row_index = 1
            for (i, load) in chunk
                n = parse(Int, i)

                fcas = load["fcas"][service.id]

                t1 = scatter(
                    name="Load $(i)",
                    mode="line",
                    x=[fcas["emin"], fcas["lb"], fcas["ub"], fcas["emax"]],
                    y=[0, fcas["amax"], fcas["amax"], 0],
                    marker=attr(
                        color="Black",
                        size=0,
                        line=attr(
                            color="Black",
                            width=2
                        )
                    ),
                    showlegend=false,
                )

                p_energy = [data["load"]["$n"]["pd"]]
                p_fcas = [data["load"]["$n"]["load_$(fcas_name(service))"]]

                p_min = load["pmin"]
                p_max = load["pmax"]

                t2 = scatter(
                    mode="markers",
                    x=p_energy,
                    y=p_fcas,
                    marker=attr(
                        color="Green",
                        size=8,
                        line=attr(
                            color="Green",
                            width=2
                        ),
                        symbol="x"
                    ),
                    showlegend=false,
                )

                t3 = scatter(
                    mode="markers",
                    x=[p_min, p_max],
                    y=[0, 0],
                    marker=attr(
                        color="Red",
                        size=0,
                        line=attr(
                            color="Red",
                            width=2
                        ),
                        symbol="line-ns"
                    ),
                    showlegend=false,
                )
                                add_trace!(fig, t1, row=row_index, col=col_index)
                add_trace!(fig, t2, row=row_index, col=col_index)
                add_trace!(fig, t3, row=row_index, col=col_index)

                if (row_index % 5 == 0)
                    row_index = 1
                    col_index += 1
                else
                    row_index += 1
                end
            end

            relayout!(fig, 
                title_text=fcas_name(service)
            )

            display(fig)
        end
    end
end

function plot_cost(data)
    gens = get_dispatchable_participants(data["gen"])

    chunks = create_chunks(sort!(collect(gens), by=x -> x[2]["index"]), 10)

    for chunk in chunks

        titles = Array{Union{Missing,String}}(missing, 2, 5)
        for (i, subchunk) in enumerate(create_chunks(chunk, 5))
            values = ["Generator $(first(j)), ($(last(j)["fuel"]))" for k in 1:1, j in subchunk]
            titles[i, 1:length(values)] = values
        end

        fig = make_subplots(rows=length(titles[1, :]), cols=2, subplot_titles=titles)

        col_index = 1
        row_index = 1

        for (i, gen) in chunk
            n = parse(Int, i)

            costs = gen["cost"]

            points = _PM.calc_pwl_points(gen["ncost"], costs, gen["pmin"], gen["pmax"])

            x = [mw for (mw, cost) in points]
            y = [cost for (mw, cost) in points]

            y_min = y[argmin(y)]
            y_max = y[argmax(y)]

            p_min = gen["pmin"]
            p_max = gen["pmax"]

            if x[end] < p_max
                dx = p_max - x[end]
                m = (y[end] - y[end-1]) / (x[end] - x[end-1])
                push!(x, p_max)
                push!(y, y[end] + m * dx)
            end

            t1 = scatter(
                name="Generator $(i)",
                x=x,
                y=y,
                mode="lines",
                showlegend=false
            )

            t2 = scatter(
                mode="markers",
                x=[data["gen"]["$n"]["pg"]],
                y=[data["gen"]["$n"]["pg_cost"]],
                marker=attr(
                    color="Green",
                    size=8,
                    line=attr(
                        color="Green",
                        width=2
                    ),
                    symbol="x"
                ),
                showlegend=false,
            )
            
            t3 = scatter(
                mode="markers",
                x=[p_min, p_max],
                y=[0, 0],
                marker=attr(
                    color="Red",
                    size=0,
                    line=attr(
                        color="Red",
                        width=2
                    ),
                    symbol="line-ns"
                ),
                showlegend=false,
            )

            add_trace!(fig, t1, row=row_index, col=col_index)
            add_trace!(fig, t2, row=row_index, col=col_index)
            add_trace!(fig, t3, row=row_index, col=col_index)

            if (row_index % 5 == 0)
                row_index = 1
                col_index += 1
            else
                row_index += 1
            end
        end

        display(fig)
    end

    loads = get_dispatchable_participants(data["load"])

    chunks = create_chunks(sort!(collect(loads), by=x -> x[2]["index"]), 10)

    for chunk in chunks

        titles = Array{Union{Missing,String}}(missing, 2, 5)
        for (i, subchunk) in enumerate(create_chunks(chunk, 5))
            values = ["Load $(first(j))" for k in 1:1, j in subchunk]
            titles[i, 1:length(values)] = values
        end

        fig = make_subplots(rows=length(titles[1, :]), cols=2, subplot_titles=titles)

        col_index = 1
        row_index = 1

        for (i, load) in chunk
            n = parse(Int, i)

            costs = load["cost"]

            points = _PM.calc_pwl_points(load["ncost"], costs, load["pmin"], load["pmax"])

            x = [mw for (mw, cost) in points]
            y = [cost for (mw, cost) in points]

            y_min = y[argmin(y)]
            y_max = y[argmax(y)]

            p_min = load["pmin"]
            p_max = load["pmax"]

            if x[end] < p_max
                dx = p_max - x[end]
                m = (y[end] - y[end-1]) / (x[end] - x[end-1])
                push!(x, p_max)
                push!(y, y[end] + m * dx)
            end

            t1 = scatter(
                name="Load $(i)",
                x=x,
                y=y,
                mode="lines",
                showlegend=false
            )

            t2 = scatter(
                mode="markers",
                x=[data["load"]["$n"]["pd"]],
                y=[data["load"]["$n"]["pd_cost"]],
                marker=attr(
                    color="Green",
                    size=8,
                    line=attr(
                        color="Green",
                        width=2
                    ),
                    symbol="x"
                ),
                showlegend=false,
            )

            t3 = scatter(
                mode="markers",
                x=[p_min, p_max],
                y=[0, 0],
                marker=attr(
                    color="Red",
                    size=0,
                    line=attr(
                        color="Red",
                        width=2
                    ),
                    symbol="line-ns"
                ),
                showlegend=false,
            )

            add_trace!(fig, t1, row=row_index, col=col_index)
            add_trace!(fig, t2, row=row_index, col=col_index)
            add_trace!(fig, t3, row=row_index, col=col_index)

            if (row_index % 5 == 0)
                row_index = 1
                col_index += 1
            else
                row_index += 1
            end
        end

        display(fig)
    end
end