function D = genda_A_design(base,mode)
% Preserve the original A's 14 factors, levels, and population compositions.
rows = tagged(base,"baseline","baseline","baseline");
spec = {'discr','discr',351,1051; ...
    'num_of_cell_around_equilibrium','target_neighborhood_cells',1,7; ...
    'tfinal','tfinal',1000,4000; 'Ts','Ts',.025,.1; ...
    'number_of_steps','number_of_steps',50,200; ...
    'rep_fix_point','rep_fix_point',20,80; 'rep_periodic','rep_periodic',5,20; ...
    'divR','divR',20,80; 'num_gen','num_gen',2,10; ...
    'selected_opt','selected_opt',2,5};
for j=1:size(spec,1)
    for k=1:2
        b=base; b.(spec{j,1})=spec{j,k+2};
        levels=["low","high"];
        rows(end+1)=tagged(b,string(spec{j,2}),levels(k),string(spec{j,k+2})); %#ok<AGROW>
    end
end
b=base; b.reltol=1e-6; b.abstol=1e-8;
rows(end+1)=tagged(b,"ode_tolerance","low","1e-6 / 1e-8");
b=base; b.reltol=1e-10; b.abstol=1e-10;
rows(end+1)=tagged(b,"ode_tolerance","high","1e-10 / 1e-10");
b=base; b.num_crossover=4; b.newcomers=4; b.num_almost_clones=1;
rows(end+1)=tagged(b,"population_size","low","10 (4/4/1 + best)");
b=base; b.num_crossover=18; b.newcomers=17; b.num_almost_clones=4;
rows(end+1)=tagged(b,"population_size","high","40 (18/17/4 + best)");
b=base; b.newcomers=4; b.num_crossover=13;
rows(end+1)=tagged(b,"newcomer_fraction","low","0.2 (4/20)");
b=base; b.newcomers=12; b.num_crossover=5;
rows(end+1)=tagged(b,"newcomer_fraction","high","0.6 (12/20)");
b=base; b.num_almost_clones=0; b.num_crossover=11;
rows(end+1)=tagged(b,"num_almost_clones","low","0");
b=base; b.num_almost_clones=4; b.num_crossover=7;
rows(end+1)=tagged(b,"num_almost_clones","high","4");
D=struct2table(rows);
assert(height(D)==29 && numel(unique(D.config_id))==29);
assert(all(D.population_size==1+D.newcomers+D.num_crossover+D.num_almost_clones));
assert(all(D.num_crossover>=1 & D.selected_opt<=D.population_size));
assert(all(mod(D.num_of_cell_around_equilibrium,2)==1));
if strcmp(mode,'smoke')
    D=D(ismember(D.config_id,["baseline","num_gen__low","Ts__high"]),:);
end
end

function cfg=tagged(base,factor,level,label)
cfg=original_A_adapter('config',base);
cfg.changed_parameter=factor; cfg.level=level; cfg.value_label=label;
cfg.config_id=factor+"__"+level;
if factor=="baseline", cfg.config_id="baseline"; end
end
