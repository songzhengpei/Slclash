package com.follow.clash.service;

import com.follow.clash.service.models.ServiceOperationResult;

interface IOperationResultInterface {
    void onResult(in ServiceOperationResult result);
}
