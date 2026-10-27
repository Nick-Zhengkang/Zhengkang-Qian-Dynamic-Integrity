classdef CellInfo < handle
    %CELLINFO Stores adaptive-grid classification counters for one cell.

    properties
        label = 'unknown'
        n_conv = 0
        n_nonconv = 0
        is_refined = false
    end

    methods
        function obj = CellInfo()
        end

        function updateLabel(obj)
            if obj.n_conv > 0 && obj.n_nonconv == 0
                obj.label = 'converging';
            elseif obj.n_nonconv > 0 && obj.n_conv == 0
                obj.label = 'nonconverging';
            elseif obj.n_conv > 0 && obj.n_nonconv > 0
                obj.label = 'mixed';
            else
                obj.label = 'unknown';
            end
        end
    end
end
